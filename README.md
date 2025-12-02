Vonage iOS SDK Samples
=======================

This repository is meant to provide some examples for you to better understand
the features of the Vonage iOS SDK. The sample applications are meant to be
used with the latest version of the
[Vonage iOS SDK](https://developer.vonage.com/en/video/client-sdks/ios/overview). Feel free to copy and
modify the source code herein for your own projects. Please consider sharing
your modifications with us, especially if they might benefit other developers
using the Vonage iOS SDK. See the [License](LICENSE) for more information.

Table Of Contents
-----------
1. [Quick Start](#quick-start)
2. [What's Inside](#whats-inside)
3. [Obtaining Vonage Credentials](#obtaining-vonage-credentials)
4. [Contributing](#development-and-contributing)
5. [Help](#getting-help)
6. [Further reading](#getting-help)

# Quick Start

 1. Get values for your Vonage **App ID**, **session ID**, and **token**.
    See [Obtaining Vonage Credentials](#obtaining-vonage-credentials)
    for important information.
 
 2. Add Vonage Client SDK Video iOS swift package by adding the https://github.com/vonage/vonage-video-client-sdk-swift.git repository as a Swift Package Dependency.

    To add a package dependency to your Xcode project, select *File* > *Swift Packages* > *Add Package Dependency* and enter its repository URL.
    
 3. In the VonageVideoManager.swift file, replace the following empty strings
    with the corresponding API key, session ID, and token values:
 
     ```swift
     // *** Fill the following variables using your own Project info  ***
     // *** https://developer.vonage.com/en/video/getting-started     ***
     // Replace with your Vonage application Id
     let kAppId = ""
     // Replace with your generated session Id
     let kSessionId = ""
     // Replace with your generated token
     let kToken = ""
     ```
 
 4. Use Xcode to build and run the app on an iOS simulator or device.

# What's Inside

You can find various sample apps written in `SwiftUI` & `UIKit` that demonstrate the Vonage iOS SDK features:

## SwiftUI
**Basic Video Chat** -- This basic application demonstrates a short path to
getting started with the Vonage iOS SDK.

**Basic Video Renderer** -- This project demonstrates how to use a **custom video renderer** in Swift to display a **black-and-white** version of a `OTPublisher` video stream using the **Vonage Video iOS SDK**

## UIKit
**Basic Video Chat** -- This basic application demonstrates a short path to
getting started with the Vonage iOS SDK.

**Custom Audio Driver** -- This project demonstrate how to use an external audio
source with the Vonage SDK. This project utilizes CoreAudio and the AUGraph API
to create an audio session suitable for voice and video communications.

**Custom Video Driver** -- This project provides classes that implement
the OTVideoCapture and OTVideoRender interfaces of the core Publisher and
Subscriber classes. Using these modules, we can see the basic workflow of
sourcing video frames from the device camera in and out of Vonage, via the
OTPublisherKit and OTSubscriberKit interfaces.

**Live Photo Capture** -- This project extends the video capture module implemented
in project 2, and demonstrates how the AVFoundation media capture APIs can be used to
simultaneously stream video and capture high-resolution photos from the same camera.

**Screen Sharing** -- This project demonstrates how to use a custom video capturer
to publish a stream that uses a UI view (instead of a camera) as the video source.

**Simple Multiparty** -- This project demonstrates how to use the Vonage iOS SDK
for a multi-party call. The application publishes audio/video from an iOS device and 
can connect to multiple subscribers. However it shows only one subscriber video at a 
time due to CPU limitations on iOS devices.

**Picture In Picture** -- This project demonstrates how to implement Picture In Picture on a 
subcribed video stream.

**FrameMetadata** -- This project shows how to set metadata (limited to 32 bytes) to a video frame, as well as how to read metadata from a video frame.
	
# Obtaining Vonage Credentials

[Step by step tutorial](https://developer.vonage.com/en/video/getting-started)

To use the Vonage platform you need a session ID, token, and API key.
You can get these values by creating a project on your [Vonage Account
Page](https://developer.vonage.com/sign-in?redirect=/en/tools) and scrolling down to the Project Tools
section of your Project page. For production deployment, you must generate the
session ID and token values using one of the [Vonage Server
SDKs](https://developer.vonage.com/en/video/server-sdks/overview).

# Development and Contributing

Interested in contributing? We :heart: pull requests! See the 
[Contribution](CONTRIBUTING.md) guidelines.

# Getting Help

We love to hear from you so if you have questions, comments or find a bug in the project, let us know! You can either:

- Open an issue on this repository
- See [Vonage support](https://api.support.vonage.com/) for support options
- Tweet at us! We're [@VonageDev](https://twitter.com/VonageDev) on Twitter
- Or [join the Vonage Developer Community Slack](https://developer.nexmo.com/community/slack)

# Further Reading

- Check out the [Developer Documentation](https://developer.vonage.com/)
- [Vonage iOS SDK reference](https://vonage.github.io/video-docs/video-ios-reference/latest/)
