/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for renderer class which perfoms Metal setup and per frame rendering
*/

@import MetalKit;

// Our platform independent render class
@interface AAPLRenderer : NSObject

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView device:(nonnull id <MTLDevice>) device;
- (void) draw:(nonnull MTKView *)view;
- (void) updateOfflineState:(nonnull MTKView *)view;
- (void) updateSize:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size;

@end
