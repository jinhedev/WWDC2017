/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of renderer class which perfoms Metal setup and per frame rendering
*/
@import simd;
@import ModelIO;
@import MetalKit;

#import "AAPLRenderer.h"
#import "AAPLMathUtilities.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "AAPLShaderTypes.h"

/// The maximum number of command buffers in flight
static const NSUInteger kMaxBuffersInFlight = 3;

/// The 256 byte aligned size of our uniform structure
static const size_t kAlignedUniformsSize = (sizeof(AAPLUniforms) & ~0xFF) + 0x100;

/// Main class performing the rendering
@implementation AAPLRenderer
{
    @public
    id <MTLDevice> _device;

    @private
    dispatch_semaphore_t _inFlightSemaphore;
    id <MTLCommandQueue> _commandQueue;

    // Metal objects
    id <MTLBuffer> _dynamicUniformBuffer;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    id <MTLTexture> _baseColorMap;
    id <MTLTexture> _normalMap;
    id <MTLTexture> _specularMap;

    /// Metal vertex descriptor specifying how vertices will by laid out
    /// for input into our render pipeline and how we'll layout our ModelIO vertices
    MTLVertexDescriptor *_mtlVertexDescriptor;

    /// Offset within _dynamicUniformBuffer to set for the current frame.
    uint32_t _uniformBufferOffset;

    /// Used to determine _uniformBufferOffset each frame.
    /// This is the current frame number modulo kMaxBuffersInFlight.
    uint8_t _uniformBufferIndex;

    /// Address to write dynamic uniforms to each frame.
    /// A function of _dynamicUniformBuffer.contents and _uniformBufferOffset.
    void* _uniformBufferAddress;

    /// Projection matrix calculated as a function of view size.
    matrix_float4x4 _projectionMatrix;

    /// Current rotation of our object in radians.
    float _rotation;

    /// MetalKit mesh containing vertex data and index buffer for our object.
    MTKMesh *_mesh;
}

/// Initialize with the MetalKit view from which we'll obtain our Metal device.
/// We'll also use this mtkView object to set the pixelformat and other properties of our drawable.
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView device:(id<MTLDevice>) device
{
    self = [super init];
    if(self)
    {
        _device = device;
        _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
        [self loadMetal:mtkView];
        [self loadAssets];
    }

    return self;
}

/// Create our metal render state objects including our shaders and
/// render state pipeline objects.
- (void) loadMetal:(nonnull MTKView *)mtkView
{
    // Create and load our basic Metal state objects.

    // Load all the shader files with a metal file extension in the project.
    id <MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

    // Calculate our uniform buffer size. We allocate kMaxBuffersInFlight instances
    // for uniform storage in a single buffer. This allows us to update uniforms in
    // a ring (i.e. triple buffer the uniforms) so that the GPU reads from one slot
    // in the ring wil the CPU writes to another. Uniform storage must be
    // aligned (to 256 bytes) to meet the requirements to be an argument in the
    // constant address space of our shading functions.
    NSUInteger uniformBufferSize = kAlignedUniformsSize * kMaxBuffersInFlight;

    // Create and allocate our uniform buffer object. Indicate shared storage so
    // that both the CPU can access the buffer.
    _dynamicUniformBuffer = [_device newBufferWithLength:uniformBufferSize
                                                 options:MTLResourceStorageModeShared];

    _dynamicUniformBuffer.label = @"UniformBuffer";

    // Load the fragment function into the library.
    id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentLighting"];

    // Load the vertex function into the library.
    id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexTransform"];

    // Create a vertex descriptor for our Metal pipeline. Specifies the layout of
    // vertices the pipeline should expect. The layout below keeps attributes used
    // to calculate vertex shader output position separate (world position, skinning,
    // tweening weights) separate from other attributes (texture coordinates, normals).
    // This generally maximizes pipeline efficiency.

    _mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];

    // Positions.
    _mtlVertexDescriptor.attributes[AAPLVertexAttributePosition].format = MTLVertexFormatFloat3;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributePosition].offset = 0;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributePosition].bufferIndex = AAPLBufferIndexMeshPositions;

    // Texture coordinates.
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeTexcoord].offset = 0;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeTexcoord].bufferIndex = AAPLBufferIndexMeshGenerics;

    // Normals.
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeNormal].format = MTLVertexFormatHalf4;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeNormal].offset = 8;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeNormal].bufferIndex = AAPLBufferIndexMeshGenerics;

    // Tangents.
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeTangent].format = MTLVertexFormatHalf4;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeTangent].offset = 16;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeTangent].bufferIndex = AAPLBufferIndexMeshGenerics;

    // Bitangents.
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeBitangent].format = MTLVertexFormatHalf4;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeBitangent].offset = 24;
    _mtlVertexDescriptor.attributes[AAPLVertexAttributeBitangent].bufferIndex = AAPLBufferIndexMeshGenerics;

    // Position Buffer Layout.
    _mtlVertexDescriptor.layouts[AAPLBufferIndexMeshPositions].stride = 12;
    _mtlVertexDescriptor.layouts[AAPLBufferIndexMeshPositions].stepRate = 1;
    _mtlVertexDescriptor.layouts[AAPLBufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;

    // Generic Attribute Buffer Layout.
    _mtlVertexDescriptor.layouts[AAPLBufferIndexMeshGenerics].stride = 32;
    _mtlVertexDescriptor.layouts[AAPLBufferIndexMeshGenerics].stepRate = 1;
    _mtlVertexDescriptor.layouts[AAPLBufferIndexMeshGenerics].stepFunction = MTLVertexStepFunctionPerVertex;

    
    // Create a reusable pipeline state.
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.sampleCount = mtkView.sampleCount;
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.vertexDescriptor = _mtlVertexDescriptor;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
    pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat;

    NSError *error = Nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState)
    {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }

    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

    // Create the command queue.
    _commandQueue = [_device newCommandQueue];
}

/// Create and load our assets into Metal objects including meshes and textures.
- (void) loadAssets
{
    NSError *error;

    // Create a ModelIO vertexDescriptor so that we format/layout our ModelIO mesh
    // vertices to fit our Metal render pipeline's vertex descriptor layout.
    MDLVertexDescriptor *modelIOVertexDescriptor =
        MTKModelIOVertexDescriptorFromMetal(_mtlVertexDescriptor);

    // Indicate how each Metal vertex descriptor attribute maps to each ModelIO attribute.
    modelIOVertexDescriptor.attributes[AAPLVertexAttributePosition].name  = MDLVertexAttributePosition;
    modelIOVertexDescriptor.attributes[AAPLVertexAttributeTexcoord].name  = MDLVertexAttributeTextureCoordinate;
    modelIOVertexDescriptor.attributes[AAPLVertexAttributeNormal].name    = MDLVertexAttributeNormal;
    modelIOVertexDescriptor.attributes[AAPLVertexAttributeTangent].name   = MDLVertexAttributeTangent;
    modelIOVertexDescriptor.attributes[AAPLVertexAttributeBitangent].name = MDLVertexAttributeBitangent;

    // Create a MetalKit mesh buffer allocator so that ModelIO  will load mesh
    // data directly into Metal buffers accessible by the GPU.
    MTKMeshBufferAllocator *metalAllocator =
        [[MTKMeshBufferAllocator alloc] initWithDevice: _device];

    // Use ModelIO to create a cylinder mesh as our object.
    MDLMesh *modelIOMesh = [MDLMesh newCylinderWithHeight:4
                                                    radii:(vector_float2){1.5, 1.5}
                                           radialSegments:60
                                         verticalSegments:1
                                             geometryType:MDLGeometryTypeTriangles
                                            inwardNormals:NO
                                                allocator:metalAllocator];

    // Have ModelIO create the tangents from mesh texture coordinates and normals.
    [modelIOMesh addTangentBasisForTextureCoordinateAttributeNamed:MDLVertexAttributeTextureCoordinate
                                              normalAttributeNamed:MDLVertexAttributeNormal
                                             tangentAttributeNamed:MDLVertexAttributeTangent];

    // Have ModelIO create bitangents from mesh texture coordinates and the newly created tangents.
    [modelIOMesh addTangentBasisForTextureCoordinateAttributeNamed:MDLVertexAttributeTextureCoordinate
                                             tangentAttributeNamed:MDLVertexAttributeTangent
                                           bitangentAttributeNamed:MDLVertexAttributeBitangent];

    // Perform the format/re-layout of mesh vertices by setting the new vertex
    // descriptor in our ModelIO mesh.
    modelIOMesh.vertexDescriptor = modelIOVertexDescriptor;

    // Create a MetalKit mesh (and submeshes) backed by Metal buffers.
    _mesh = [[MTKMesh alloc] initWithMesh:modelIOMesh
                                   device:_device
                                    error:&error];

    if(!_mesh || error)
    {
        NSLog(@"Error creating MetalKit mesh %@", error.localizedDescription);
    }

    // Use MetalKit to load textures from our asset catalog (Assets.xcassets).
    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];

    // Load our textures with shader read using private storage.
    NSDictionary *textureLoaderOptions =
    @{
      MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
      MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
      };

    _baseColorMap = [textureLoader newTextureWithName:@"CanBaseColorMap"
                                          scaleFactor:1.0
                                               bundle:nil
                                              options:textureLoaderOptions
                                                error:&error];

    if(!_baseColorMap || error)
    {
        NSLog(@"Error creating base color texture %@", error.localizedDescription);
    }

    _normalMap = [textureLoader newTextureWithName:@"CanNormalMap"
                                       scaleFactor:1.0
                                            bundle:nil
                                           options:textureLoaderOptions
                                             error:&error];
    if(!_normalMap || error)
    {
        NSLog(@"Error creating normal map texture %@", error.localizedDescription);
    }

    _specularMap = [textureLoader newTextureWithName:@"CanSpecularMap"
                                         scaleFactor:1.0
                                              bundle:nil
                                             options:textureLoaderOptions
                                               error:&error];

    if(!_specularMap || error)
    {
        NSLog(@"Error creating specular texture %@", error.localizedDescription);
    }

}

/// Update the location to which we can write dynamic data for this
/// frame to our Metal buffers.
- (void) updateDynamicBufferState
{
    // Update the location(s) to which we'll write to in our dynamically changing
    // Metal buffers for the current frame (i.e. update our slot in the ring buffer
    // used for the current frame).

    // Non-rendering update 1 of 2.
    _uniformBufferIndex = (_uniformBufferIndex + 1) % kMaxBuffersInFlight;

    _uniformBufferOffset = kAlignedUniformsSize * _uniformBufferIndex;

    _uniformBufferAddress = ((uint8_t*)_dynamicUniformBuffer.contents) + _uniformBufferOffset;
}

/// Update any game state (including updating dynamically changing Metal buffer)
- (void) updateGameState
{
    AAPLUniforms * uniforms = (AAPLUniforms*)_uniformBufferAddress;

    vector_float3 ambientLightColor = {0.02, 0.02, 0.02};
    uniforms->ambientLightColor = ambientLightColor;

    vector_float3 directionalLightDirection = vector_normalize ((vector_float3){0.0,  0.0, 1.0});

    uniforms->directionalLightInvDirection = -directionalLightDirection;

    vector_float3 directionalLightColor = {.7, .7, .7};
    uniforms->directionalLightColor = directionalLightColor;;

    uniforms->materialShininess = 2;

    const vector_float3   modelRotationAxis = {1, 0, 0};
    const matrix_float4x4 modelRotationMatrix = matrix4x4_rotation (_rotation, modelRotationAxis);
    const matrix_float4x4 modelMatrix   = modelRotationMatrix;

    const vector_float3 cameraTranslation = {0.0, 0.0, -8.0};
    const matrix_float4x4 viewMatrix = matrix4x4_translation (-cameraTranslation);
    const matrix_float4x4 viewProjectionMatrix  = matrix_multiply (_projectionMatrix, viewMatrix);

    uniforms->cameraPos = cameraTranslation;
    uniforms->modelMatrix = modelMatrix;
    uniforms->modelViewProjectionMatrix = matrix_multiply (viewProjectionMatrix, modelMatrix);

    // The normal matrix is typically the inverse transpose of a 3x3 matrix created
    // from the upper-left elements in the 4x4 model matrix. In this case, we don't
    // need to perform the expensive inverse and transpose operations since this is
    // only required when scaling is non-uniform. Thus it's unnecessary to do all of
    // the following:
    //      uniforms->normalMatrix = matrix_inverse_transpose(matrix3x3_upper_left(modelMatrix))
    //
    // We can simply take the upper-left 3x3 elements of the model matrix.
    uniforms->normalMatrix = matrix3x3_upper_left(modelMatrix);
    
    // Non-rendering update 2 of 2.
    _rotation += .01;
}

- (void)updateOfflineState:(nonnull MTKView *)view
{
    _uniformBufferIndex = (_uniformBufferIndex + 1) % kMaxBuffersInFlight;
    _rotation += .01;
}

/// Called whenever view changes orientation or layout is changed
- (void)updateSize:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // React to resize of our draw rect.  In particular, update our perspective matrix.
    // Update the aspect ratio and projection matrix since the view orientation or
    // size has changed
    float aspect = size.width / (float)size.height;
    _projectionMatrix = matrix_perspective_left_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0);
}

/// Called whenever the view needs to render
- (void)draw:(nonnull MTKView *)view
{
    // Wait to ensure only kMaxBuffersInFlight are getting proccessed by any
    // stage in the Metal pipeline (App, Metal, Drivers, GPU, etc).
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

    [self updateDynamicBufferState];

    [self updateGameState];
    
    // Create a new command buffer for each renderpass to the current drawable.
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    // If we've gotten a renderPassDescriptor we can render to the drawable,
    // otherwise we'll skip any rendering this frame because we have no drawable
    // to draw to.
    // Note: With GPU switches, currentRenderPassDescriptor can sometimes be nil.
    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder so we can render into something.
        id <MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Push a debug group allowing us to identify render commands in the GPU
        // Frame Capture tool
        [renderEncoder pushDebugGroup:@"DrawMesh"];

        // Set render command encoder state.
        [renderEncoder setCullMode:MTLCullModeBack];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setDepthStencilState:_depthState];

        // Set any buffers fed into our render pipeline.
        [renderEncoder setVertexBuffer:_dynamicUniformBuffer
                                offset:_uniformBufferOffset
                               atIndex:AAPLBufferIndexUniforms];

        [renderEncoder setFragmentBuffer:_dynamicUniformBuffer
                                  offset:_uniformBufferOffset
                                 atIndex:AAPLBufferIndexUniforms];

        // Set mesh's vertex buffers.
        for (NSUInteger bufferIndex = 0; bufferIndex < _mesh.vertexBuffers.count; bufferIndex++)
        {
            MTKMeshBuffer *vertexBuffer = _mesh.vertexBuffers[bufferIndex];
            if((NSNull*)vertexBuffer != [NSNull null])
            {
                [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                        offset:vertexBuffer.offset
                                       atIndex:bufferIndex];
            }
        }

        // Set any textures read/sampled from our render pipeline.
        [renderEncoder setFragmentTexture:_baseColorMap
                                  atIndex:AAPLTextureIndexBaseColor];

        [renderEncoder setFragmentTexture:_normalMap
                                  atIndex:AAPLTextureIndexNormal];

        [renderEncoder setFragmentTexture:_specularMap
                                  atIndex:AAPLTextureIndexSpecular];

        // Draw each submesh of our mesh.
        for(MTKSubmesh *submesh in _mesh.submeshes)
        {
            [renderEncoder drawIndexedPrimitives:submesh.primitiveType
                                      indexCount:submesh.indexCount
                                       indexType:submesh.indexType
                                     indexBuffer:submesh.indexBuffer.buffer
                               indexBufferOffset:submesh.indexBuffer.offset];
        }

        [renderEncoder popDebugGroup];

        // We're done encoding commands.
        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Add completion hander which signals _inFlightSemaphore when Metal and the GPU
    // has fully finished proccssing the commands we're encoding this frame. This
    // indicates when the dynamic buffers, that we're writing to this frame, will no
    // longer be needed by Metal and the GPU, meaning we can change the buffer
    // contents without corrupting the rendering.
    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
     {
         dispatch_semaphore_signal(block_sema);
     }];

    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
    
}

@end
