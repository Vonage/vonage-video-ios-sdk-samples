Basic Video Renderer Sample App
===============================

This example demonstrates how to use a **custom video renderer** in Swift to display a **black-and-white** version of a `OTPublisher` video stream using the **Vonage Video iOS SDK**.

Quick Start
-----------

To use this application:

1. You need to set values for the `kAppId`, `kSessionId` and `kToken` constants. Follow the [Getting started](https://developer.vonage.com/en/video/getting-started) guide to learn how to obtain these credentials.

2. When you run the application, it connects to a session and
   publishes an audio-video stream from your device to the session.

Tutorial
-----------

## Overview

After initializing the `OTPublisher` object in the `VonageVideoManager`, we assign its `videoRender` property to an instance of our custom renderer `CustomVideoRender`.

## VonageVideoManager.swift

```swift
import OpenTok
import SwiftUI

let renderer = CustomVideoRender()

private lazy var publisher: OTPublisher? = {
    let settings = OTPublisherSettings()
    settings.name = UIDevice.current.name
    return OTPublisher(delegate: self, settings: settings)
}()

private func doPublish() {
    ...
    
    // Publish & assign renderer
    guard let publisher else { return }
    publisher.videoRender = renderer
    session?.publish(publisher, error: &error)
    
    // Setup view
    guard let pubView = publisher.view else { return }
    pubView.frame = CGRect(x: 0, y: 0, width: 250, height: 250)
    renderer.view.frame = CGRect(x: 0, y: 0, width: 250, height: 250)
    pubView.addSubview(renderer.view)
    
    // Wrap structure allows displaying UIViews in SwiftUI
    DispatchQueue.main.async {
        self.pubView = AnyView(Wrap(pubView))
    }
}
```

## CustomVideoRender.swift

CustomVideoRender is a custom class that implements the OTVideoRender protocol defined by the Vonage iOS SDK.
This protocol allows you to define your own custom renderer for a publisher or subscriber video stream.

```swift
final class CustomVideoRender: NSObject, OTVideoRender {
    let view = CustomRenderView(frame: .zero)
    
    func renderVideoFrame(_ frame: OTVideoFrame) {
        view.renderVideoFrame(frame)
    }
}
```

## CustomRenderView.swift

CustomRenderView is a subclass of `UIView` responsible for drawing the black-and-white image on screen.
It takes each video frame, converts it to grayscale, creates a CGImage, and triggers a redraw.

```swift
class CustomRenderView: UIView {
    private var renderQueue = DispatchQueue.global(qos: .userInitiated)
    private var image: CGImage? = nil
    
    func renderVideoFrame(_ frame: OTVideoFrame) {
        let frameToRender = frame
        
        renderQueue.sync {
            // Release previous image if any exists
            if image != nil {
                image = nil
            }
            guard let format = frame.format else { return }
            let width = Int(format.imageWidth)
            let height = Int(format.imageHeight)
            let bufferSize = width * height * 3
            
            guard let rawYPlane = frameToRender.planes?.pointer(at: 0) else { return }
            let yplane = rawYPlane.bindMemory(to: UInt8.self, capacity: width * height)
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            
            // Fill RGB buffer with grayscale image (Y only)
            for i in 0..<height {
                for j in 0..<width {
                    let pixelIndex = (i * width * 3) + (j * 3)
                    let yValue = yplane[(i * width) + j]
                    buffer[pixelIndex] = yValue
                    buffer[pixelIndex + 1] = yValue
                    buffer[pixelIndex + 2] = yValue
                }
            }
            
            // Release buffer when CGDataProvider is done
            let releaseCallback: CGDataProviderReleaseDataCallback = { _, data, _ in
                data.deallocate()
            }
            
            guard let provider = CGDataProvider(dataInfo: nil, data: buffer, size: bufferSize, releaseData: releaseCallback) else {
                buffer.deallocate()
                return
            }
            
            // Create CGImage
            image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 24,
                bytesPerRow: 3 * width,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.setNeedsDisplay()
            }
        }
    }
        
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        var imgCopy: CGImage?
        
        renderQueue.sync {
            if let currentImage = image {
                imgCopy = currentImage.copy()
            }
        }
        
        if let img = imgCopy {
            context.draw(img, in: self.bounds)
        }
    }
}
```

## Explanation

`OTPublisher.videoRender`
Assigns our custom renderer to handle the video output of the publisher.

`OTVideoRender` protocol
Requires implementing renderVideoFrame(_:), which provides a OTVideoFrame object for each frame.

`CustomRenderView`
Converts the Y (luminance) plane into grayscale RGB values.
Builds a CGImage and draws it to the view.

Grayscale Conversion
Each pixel’s luminance (Y value) is copied into all three color channels (R, G, B), resulting in a black-and-white frame. 
    
Additional Notes
-----------

 To add a second publisher (which will display as a subscriber in your emulator), either run the app a second time in an iOS device or use the OpenTok Playground to connect to the session in a supported web browser by following the steps below:

1. Go to [Vonage Playground](https://tools.vonage.com/video/playground) (must be logged into your [Account](https://dashboard.vonage.com/))
2. Select the **Join existing session** tab
3. Copy the session ID you used in your project file and paste it in the **Session ID** input field
4. Click **Join Session**
5. On the next screen, click **Connect**, then click **Publish Stream**
6. You can adjust the Publisher options (not required), then click **Continue** to connect and begin publishing and subscribing


Configuration Notes
-------------------

*   You can test in the iOS Simulator or on a supported iOS device. However, the
    XCode iOS Simulator does not provide access to the camera. When running in
    the iOS Simulator, an OTPublisher object uses a demo video instead of the
    camera.

[1]: https://dashboard.vonage.com/
[2]: https://developer.vonage.com/en/video/server-sdks/overview
