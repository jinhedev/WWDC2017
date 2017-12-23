/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Include header shared between this Metal shader code and C code executing
// Metal API commands.
#import "AAPLShaderTypes.h"

// Per-vertex inputs fed by vertex buffer laid out with MTLVertexDescriptor
// in the Metal API.
typedef struct
{
    float3 position [[attribute(AAPLVertexAttributePosition)]];
    float2 texCoord [[attribute(AAPLVertexAttributeTexcoord)]];
    half3 normal    [[attribute(AAPLVertexAttributeNormal)]];
    half3 tangent   [[attribute(AAPLVertexAttributeTangent)]];
    half3 bitangent [[attribute(AAPLVertexAttributeBitangent)]];
} Vertex;

// Vertex shader outputs and per-fragmeht inputs. Includes clip-space position
// and vertex outputs interpolated by rasterizer and fed to each fragment generated
// by clip-space primitives.
typedef struct
{
    float4 position [[position]];
    float2 texCoord;

    half3  worldPos;
    half3  tangent;
    half3  bitangent;
    half3  normal;
} ColorInOut;

/// Vertex function.
vertex ColorInOut vertexTransform(Vertex in [[stage_in]],
                                  constant AAPLUniforms & uniforms [[ buffer(AAPLBufferIndexUniforms) ]])
{
    ColorInOut out;

    // Make in.position a float4 to perform 4x4 matrix math on it.
    // Then, calculate the position of our vertex in clip space and output for
    // clipping and rasterization.
    out.position = uniforms.modelViewProjectionMatrix * float4(in.position, 1.0);

    // Pass along the texture coordinate of our vertex such which we'll use to
    // sample from texture's in our fragment function.
    out.texCoord = in.texCoord;

    // Rotate our tangents, bitangents, and normals by the normal matrix.
    half3x3 normalMatrix = half3x3(uniforms.normalMatrix);
    out.tangent   = normalMatrix * in.tangent;
    out.bitangent = normalMatrix * in.bitangent;
    out.normal    = normalMatrix * in.normal;
    out.worldPos = (half3) (uniforms.modelMatrix * float4(in.position, 1.0)).xyz;

    return out;
}

/// Fragment function.
fragment float4 fragmentLighting(ColorInOut in [[stage_in]],
                                 constant AAPLUniforms & uniforms [[ buffer(AAPLBufferIndexUniforms) ]],
                                 texture2d<half> baseColorMap [[ texture(AAPLTextureIndexBaseColor) ]],
                                 texture2d<half> normalMap    [[ texture(AAPLTextureIndexNormal) ]],
                                 texture2d<half> specularMap  [[ texture(AAPLTextureIndexSpecular) ]])
{
    constexpr sampler linearSampler (mip_filter::linear,
                                     mag_filter::linear,
                                     min_filter::linear);

    const half4 baseColorSample = baseColorMap.sample (linearSampler, in.texCoord.xy);
    half3 normalSampleRaw = normalMap.sample (linearSampler, in.texCoord.xy).xyz;
    // The x and y coordinates in a normal map (red and green channels) are mapped
    // from [-1;1] to [0;255].
    // As the sampler returns a value in [0 ; 1], we need to do:
    normalSampleRaw.xy = normalSampleRaw.xy * 2.0 - 1.0;
    const half3 normalSample    = normalize(normalSampleRaw);
    const half  specularSample  = specularMap.sample  (linearSampler, in.texCoord.xy).x;

    // The per-vertex vectors have been interpolated, thus we need to normalize them again:
    in.tangent   = normalize (in.tangent);
    in.bitangent = normalize (in.bitangent);
    in.normal    = normalize (in.normal);

    half3x3 tangentMatrix = half3x3(in.tangent, in.bitangent, in.normal);

    float3 normal = (float3) (tangentMatrix * normalSample);

    // Calculate the contribution of the directional light as a sum of diffuse
    // and specular terms.
    float3 directionalContribution = float3(0);
    float3 specularTerm = float3(0);
    {
        // Light falls off based on how closely aligned the surface normal is
        // to the light direction
        float nDotL = saturate(dot(normal, uniforms.directionalLightInvDirection));

        // The diffuse term is the product of the light color, the surface material
        // reflectance, and the falloff
        float3 diffuseTerm = uniforms.directionalLightColor * nDotL;

        // Apply specular lighting...

        // 1) Calculate the halfway vector between the light direction and the
        // direction they eye is looking
        float3 eyeDir = normalize (uniforms.cameraPos - float3(in.worldPos));
        float3 halfwayVector = normalize(uniforms.directionalLightInvDirection + eyeDir);

        // 2) Calculate the reflection amount by evaluating how the halfway vector
        // matches the surface normal
        float reflectionAmount = saturate(dot(normal, halfwayVector));

        // 3) Calculate the specular intensity by powering our reflection amount
        // to our object's shininess
        float specularIntensity = saturate(powr(reflectionAmount, uniforms.materialShininess));

        // 4) Obtain the specular term by multiplying the intensity by our light's
        // color
        specularTerm = uniforms.directionalLightColor * specularIntensity * float(specularSample);

        // The base color sample is actually the diffuse color of the material
        float3 baseColor = float3(baseColorSample.xyz);

        // The ambient contribution is an approximation for global, indirect lighting,
        // and simply added to the calculated lit color value below.

        // Calculate diffuse contribution from this light: the sum of the diffuse
        // and ambient * albedo.
        directionalContribution = baseColor * (diffuseTerm + uniforms.ambientLightColor);
    }

    // Now that we have the contributions our light sources in the scene, we sum
    // them together to get the fragment's lit color value.
    float3 color = specularTerm + directionalContribution;

    // We return the color we just computed and the alpha channel of our baseColorMap
    // for this fragment's alpha value.
    return float4(color, baseColorSample.w);
}
