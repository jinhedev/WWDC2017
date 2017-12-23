# Metal Device Selection and Fallback

This sample demonstrates smooth switching between multiple Metal devices. By default, the sample chooses the system device associated with the current display and then performs some rendering work.

The sample demonstrates how to observe and handle device changes; it also demonstrates how to obtain, select, and switch between any GPUs.

## Overview

### What does this sample demonstrate?

How to write a Metal app that is multi-GPU aware so you can make informed runtime decisions for choosing the most performant render device among all available devices.
The sample listens to and handles different notifications that capture the app's screen changes and preferred GPU switches at runtime.

Apps are strongly recommended to use the rendering device that corresponds to the system device. This is the most performant option since it avoids expensive data transfers between the GPU that renders your app's work and the GPU that drives the user's system.

Ultimately, the device selection decision is up to you. For example, you may choose a different GPU if your app performs non-rendering work (e.g. compute) or your app's rendering performance benefits outweigh your app's data transfer costs.

### What problem does this sample solve?

With the introduction of an external GPU, the Metal device list can vary at runtime. Furthermore, external displays and screen changes may cause the system device to vary at runtime as well.

Users can plug or unplug these peripherals at any time, so Metal apps should be aware of these changes and respond to them appropriately. For example, if the user switches to a different display then you should also switch your Metal work to that display's GPU. Otherwise, your app might keep working on a different GPU and incur a significant drop in its frame rate.

### How does this sample solve the problem?

**Obtaining all available Metal devices**

Once the sample successfully initializes the renderer on each device, it adds that device to the supported list.

The [`MTLCopyAllDevices()`](https://developer.apple.com/documentation/metal/1433367-mtlcopyalldevices) function returns an array of  all the available Metal devices.
```
NSArray<id<MTLDevice>> * availableDevices = MTLCopyAllDevices();
```

Note: You might want to initialize the renderers and their assets at launch time to achieve seamless runtime device switches.

**Obtaining the display ID**

The `deviceDescription` property contains the ID of the display where the current window screen is being displayed.

```
CGDirectDisplayID viewDisplayID = (CGDirectDisplayID) [[_view.window.screen.deviceDescription objectForKey:@"NSScreenNumber"] unsignedIntegerValue];
```

Note: Accessing the `window` property in the `viewDidLoad` method returns `nil`. Therefore, this query must be made at a later stage; in this sample, the query is made in the `viewDidAppear` method.

**Obtaining a Metal device for a given display**

The `CGDirectDisplayCopyCurrentMetalDevice()` function returns the Metal device associated with the current display.

```
id<MTLDevice> newPreferredDevice = CGDirectDisplayCopyCurrentMetalDevice(viewDisplayID);
```

Apps are strongly recommended to use this device as their render device, to avoid unnecessary data transfers.

**Notifications**

There are two important notifications that cover most of the screen changes.

* `NSApplicationDidChangeScreenParametersNotification` — Posted when the configuration of the displays attached to the Mac is changed. For example, system device changes.

* `NSWindowDidChangeScreenNotification` — Posted whenever a portion of an `NSWindow` object’s frame moves onto or off of a screen. For example, when the window moves between different display screens.

**Achieving a seamless rendering switch**

While all draw calls are committed to the current render device that your app has chosen, your app should still update the render state on the other offline render devices. This will ensure smooth switches between any render devices by picking the correct frame state information needed for a given frame.

In this sample, the `drawInMTKView:` method calls the `draw:` method on the current render device and calls the `updateOfflineState:` method on the other offline devices. The `updateOfflineState:` method updates state information needed for drawing a frame, such as rotation data and the uniform buffer index, but it does not perform any actual drawing.

```
// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view {
    // draw only online device renderer.
    [_renderer[_currentRendererIndex] draw:view];

    // and just update state of offline device renderers.
    for (uint32 i = 0; i < [_supportedDevices count]; i++) {
        if (_currentRendererIndex != i) {
            [_renderer[i] updateOfflineState:view];
        }
    }
}
```

## Requirements

- This sample is only supported on macOS.
- Currently this sample code has limited support for an external GPU. The external GPU should be attached to your Mac when it is at the login screen so that the macOS WindowServer can restart and recognize the external GPU.
