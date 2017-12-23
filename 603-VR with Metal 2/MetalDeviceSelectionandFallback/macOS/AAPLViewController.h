/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for our macOS view controller
*/

@import Cocoa;
@import MetalKit;

#import "AAPLRenderer.h"

// Our macOS specific view controller
@interface AAPLViewController : NSViewController<MTKViewDelegate>

- (void) launchWithPreferedDevice;
- (void) handleScreenChanges:(NSNotification *)notification;
- (void) handleDeviceSelection: (id)device;

@end
