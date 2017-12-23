/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of our macOS Application Delegate
*/

#import "AAPLAppDelegate.h"

@implementation AAPLAppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

@end
