Custom Audio Driver Sample App
===============================

This example demonstrates how to use a **custom audio renderer** in Swift to
play a short ringtone while waiting for the subscriber to connect to the client
device. This is achieved by extending the sample audio driver with an AVAudioPlayer controller.

Quick Start
-----------

To use this application:

1. You need to set values for the `kAppId`, `kSessionId` and `kToken` constants. Follow the [Getting started](https://developer.vonage.com/en/video/getting-started) guide to learn how to obtain these credentials.

2. When you run the application, it connects to a session and
   publishes an audio-video stream from your device to the session.

## Overview

In this sample, the `VonageVideoManager` setup contains an immediate call to set the audio device driver. After connecting via `doConnect()` and setting `Publisher` the audio device driver will begin playing back an audio file, that will act as a ringtone:

```
public func setup() {
    if let path = Bundle.main.path(forResource: "bananaphone", ofType: "mp3") {
        myAudioDevice = AudioDeviceRingtone(ringtone: URL(fileURLWithPath: path))
        OTAudioDeviceManager.setAudioDevice(myAudioDevice)
    }
    doConnect()
}
```

Additionally, once the device has connected to a subscriber stream, a call is
issued to stop playback of the ringtone:

```
func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
    print("subscriberDidConnectToStream (\(subscriber?.stream?.connection.connectionId ?? ""))")
    
    // Stop ringtone from playing, as the subscriber will connect shortly
    myAudioDevice?.stopRingtone()
    guard let view = self.subscriber?.view else { return }
    subView = AnyView(Wrap(view))
}
```
    
Additional Notes
-----------

 To add a second publisher (which will display as a subscriber in your simulator), either run the app a second time in an iOS device or use the OpenTok Playground to connect to the session in a supported web browser by following the steps below:

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
