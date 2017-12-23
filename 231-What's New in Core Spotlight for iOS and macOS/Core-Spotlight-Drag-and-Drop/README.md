# Core Spotlight Support

This sample demonstrates how to implement Core Spotlight extensions, and how to support previews and drag and drop for them.

## Overview

[Core Spotlight](https://developer.apple.com/documentation/corespotlight) allows you to index your app's content so that Spotlight can display it in its search results. It is available on both macOS and iOS.
Core Spotlight items that are displayed in Spotlight's search results can show a preview when being peek and popped on iOS and when selected on macOS. This sample shows how to implement the Quick Look Preview extensions to support these previews. Finally, this sample also includes code to demonstrate how Core Spotlight items can support drag and drop on iOS.

## Getting Started

CoreSpotlight indexing should start when the app first registers as an index delegate. On iOS, once the app is installed, and not running, you can trigger the app extension from Settings > Developer > Core Spotlight Testing. It is recommended to run the main apps first before trying the preview extensions so that Spotlight can index the Core Spotlight items and allow you to find the content to be previewed. To view the previews, search for the demo app content, i.e. "Bob the Bench", in Spotlight and either peek and pop on iOS or select it in macOS. You can also view the preview in the QuickLookSimulator by selecting QuickLookSimulator as the app to launch when running the `PicturesPreviewExtension (macOS)` target.

## Build Requirements

Xcode 9.0 or later; iOS 11.0 SDK or later; macOS 10.13 SDK or later

## Runtime Requirements

iOS 11.0 or later; macOS 10.13 or later
