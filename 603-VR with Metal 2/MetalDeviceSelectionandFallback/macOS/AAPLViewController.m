/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of our macOS view controller
*/

#import "AAPLViewController.h"
#import "AAPLRenderer.h"

// Default indices of the two drop down lists
static int const AAPLSystemPreferredDeviceIndex = 0;
static int const AAPLCustomSelectedDeviceIndex  = 1;

@implementation AAPLViewController
{
    MTKView *_view;

    NSMutableArray<AAPLRenderer*> *_renderer;
    NSUInteger _currentRendererIndex;

    NSMutableArray<id<MTLDevice>> *_supportedDevices;
    NSUInteger _currentDeviceIndex;

    id<MTLDevice> _systemPreferredDevice;

    // UI elements
    IBOutlet NSTextField *_systemPreferredDeviceLabel;
    IBOutlet NSPopUpButton *_supportedDeviceList;
    IBOutlet NSPopUpButton *_devicePreferenceList;
}

// Called whenever the drawableSize of the view will change
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Udate all renderers with the new size
    for(uint32 i = 0; i < [_supportedDevices count]; i++)
    {
        [_renderer[i] updateSize:view drawableSizeWillChange:size];
    }
}

// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view
{
    // Draw only online device renderer.
    [_renderer[_currentRendererIndex] draw:view];

    // Only update state of offline device renderers (without actually issuing any any Metal
    //   commands on the other devices)
    for(uint32 i = 0; i < [_supportedDevices count]; i++)
    {
        if(_currentRendererIndex != i)
        {
            [_renderer[i] updateOfflineState:view];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Init preference button.
    [_devicePreferenceList removeAllItems];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"System Preferred Selection"
                                                  action:nil
                                           keyEquivalent:@""];
    [_devicePreferenceList.menu addItem:item];

    // init device list button.
    [_supportedDeviceList removeAllItems];
    _supportedDeviceList.enabled = false;

    // init system device label.
    _systemPreferredDeviceLabel.stringValue = @"";

    // Query all supported metal devices.
    NSArray<id<MTLDevice>> * availableDevices = MTLCopyAllDevices();

    if(availableDevices == nil || ([availableDevices count] == 0))
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
    }
    else
    {
        // init view
        _view = (MTKView *)self.view;
        _view.delegate = self;
        _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        _view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
        _view.sampleCount = 1;

        // initialize all supported device renderers.
        _renderer = [NSMutableArray new];
        _supportedDevices = [NSMutableArray new];

        //  Initialize our renderer for all devices.  Even though app will only render on one
        //    device at a time, we will initializa our renderer on each device now.  This way,
        //    if a new device becomes avaliable, the window is moved on to a display driven by
        //    by another device the renderer can immediately switch to that device.  Otherwise
        //    the app would need to initialize the renderer when the switch occurred.  This would
        //    cause stall to rendering during the switch as the renderer would need to recreate
        //    new Metal objects for the new device.

        for(uint32 i = 0; i < [availableDevices count]; i++)
        {
            id<MTLDevice> device = [availableDevices objectAtIndex:i];
            [_renderer addObject:(AAPLRenderer *)[[AAPLRenderer alloc] initWithMetalKitView:_view device:(id<MTLDevice>)device]];

            if(!_renderer[i])
            {
                NSLog(@"Renderer initialization failed for device %@", device.name);
                return;
            }

            NSLog(@"Added device %@ to supported device list at %i", device.name, i);
            [_supportedDevices addObject:(id<MTLDevice>)device];

            // Now add device to UI list for user to select.
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:device.name action:nil keyEquivalent:@""];
            item.representedObject = device;
            [_supportedDeviceList.menu addItem:item];
        }

        // Add "Custom" item to device preference button only if you have more than 1 device support.
        if([_supportedDevices count] > 1)
        {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Custom Selection"
                                                          action:nil
                                                   keyEquivalent:@""];
            [_devicePreferenceList.menu addItem:item];
        }

        // Init handler for drawable size changes
        [self mtkView:_view drawableSizeWillChange:_view.drawableSize];
    }
}

- (void) viewDidAppear
{
    [self launchWithPreferedDevice];
}

- (void) launchWithPreferedDevice
{
    if(_systemPreferredDevice == nil && [_supportedDevices count] > 0)
    {
        // Query for preferred display for this view
        CGDirectDisplayID viewDisplayID =
            (CGDirectDisplayID) [[_view.window.screen.deviceDescription objectForKey:@"NSScreenNumber"] unsignedIntegerValue];

        // Query for the Metal device driving this display
        id<MTLDevice> preferredDevice = CGDirectDisplayCopyCurrentMetalDevice(viewDisplayID);

        if(viewDisplayID != 0 && preferredDevice != nil)
        {
            // Launch renderer using system preferred device.
            for(uint32 i = 0; i < [_supportedDevices count]; i++)
            {
                if(preferredDevice == _supportedDevices[i])
                {
                    NSLog(@"got preferred device as %@", _supportedDevices[i].name);
                    _currentRendererIndex = i;
                    _currentDeviceIndex = i;
                    _systemPreferredDevice = _supportedDevices[i];
                    _view.device = _supportedDevices[i];
                    _systemPreferredDeviceLabel.stringValue = _systemPreferredDevice.name;
                }
            }

            // Register to NSApplicationDidChangeScreenParametersNotification which will trigger
            //  if they system's display configuration changed
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleScreenChanges:)
                                                         name:NSApplicationDidChangeScreenParametersNotification
                                                       object:nil];

            // Register to NSWindowDidChangeScreenNotification which will trigger if the window
            //   changed screens
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleScreenChanges:)
                                                         name:NSWindowDidChangeScreenNotification
                                                       object:nil];
        }
        else
        {
            // Fallback case just select first supported device.
            _view.device = _supportedDevices[_currentDeviceIndex];
            _systemPreferredDevice = _supportedDevices[_currentDeviceIndex];
            _systemPreferredDeviceLabel.stringValue = _systemPreferredDevice.name;
            _supportedDeviceList.enabled = false;
        }

        // update current device selection in popup box
        for (NSMenuItem *item in _supportedDeviceList.menu.itemArray)
        {
            if ([_view.device isEqual:item.representedObject])
            {
                [_supportedDeviceList selectItem:item];
            }
        }
    }
}

// Called if there are changes to screen when and NSApplicationDidChangeScreenParametersNotification
//   occurs or when the window is moved to another screen and NSWindowDidChangeScreenNotification
//   occurs
- (void) handleScreenChanges:(NSNotification *)notification
{
    CGDirectDisplayID viewDisplayID =
        (CGDirectDisplayID) [[_view.window.screen.deviceDescription objectForKey:@"NSScreenNumber"] unsignedIntegerValue];

    id<MTLDevice> newPreferredDevice = CGDirectDisplayCopyCurrentMetalDevice(viewDisplayID);
    NSLog(@"Notification on current system preferred device %@", newPreferredDevice.name);

    // Update system preferred device
    if(_systemPreferredDevice != newPreferredDevice)
    {
        for(uint32 i = 0; i < [_supportedDevices count]; i++)
        {
            if(newPreferredDevice == _supportedDevices[i])
            {
                _systemPreferredDevice = _supportedDevices[i];
                _systemPreferredDeviceLabel.stringValue = _systemPreferredDevice.name;
            }
        }
    }

    // Switch to system preferred device only if user selected "system" as preference.
    if(_devicePreferenceList.indexOfSelectedItem == AAPLSystemPreferredDeviceIndex &&
       _supportedDevices[_currentDeviceIndex] != _systemPreferredDevice)
    {
        [self handleDeviceSelection:_systemPreferredDevice];
    }
}

- (void) handleDeviceSelection: (id)device
{
    // Nothing to be done if current device is same
    if( _supportedDevices[_currentDeviceIndex] == device)
    {
        return;
    }

    // Switch devices otherwise
    for(uint32 i = 0; i < [_supportedDevices count]; i++)
    {
        // Found new device in supported list.
        if(_supportedDevices[i] == device)
        {
            _currentDeviceIndex   = i;
            _currentRendererIndex = i;

            // Switch view to new device.
            _view.device = _supportedDevices[_currentDeviceIndex];
            _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
            _view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
            _view.sampleCount = 1;

            // Update UI List state.
            for (NSMenuItem *item in _supportedDeviceList.menu.itemArray)
            {
                if ([_view.device isEqual:item.representedObject])
                {
                    [_supportedDeviceList selectItem:item];
                }
            }

            NSLog(@"Rendering using device: %@", _view.device.name);

            // Call draw on this new device.
            [_renderer[_currentRendererIndex] draw:_view];
        }
    }
}

// Handles switch to user selected device.
- (IBAction)changeRenderer:(id)sender
{
    id<MTLDevice> device = _supportedDeviceList.selectedItem.representedObject;
    NSLog(@"Application requested switch to %@", device.name);
    [self handleDeviceSelection:device];
}

// Handles user changes to device preference.
- (IBAction)changePreference:(id)sender {
    
    NSInteger index = _devicePreferenceList.indexOfSelectedItem;

    // User selected system device as preference.
    if(index == AAPLSystemPreferredDeviceIndex)
    {
        // Disable supported list UI element so user cannot select device from list
        //   and switch to system preferred device.
        _supportedDeviceList.enabled = false;
        [self handleDeviceSelection:_systemPreferredDevice];
    }
    // User selected custom device as preference.
    else if(index == AAPLCustomSelectedDeviceIndex)
    {
        // Enable supported list UI element so user can select device from list
        //   and switch to user preferred device if need be.
        _supportedDeviceList.enabled = true;
        [self handleDeviceSelection:_supportedDeviceList.selectedItem.representedObject];
    }
}

// Remove observers upon exit.
- (void) dealloc
{
    // Remove NSApplicationDidChangeScreenParametersNotification observer
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSApplicationDidChangeScreenParametersNotification
                                                  object:nil];
    
    // Remove NSWindowDidChangeScreenNotification observer
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowDidChangeScreenNotification
                                                  object:nil];
}

@end
