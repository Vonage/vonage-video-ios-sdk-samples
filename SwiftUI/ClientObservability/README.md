# Client Observability Sample App

This application, built on top of Basic Video Chat, shows how to  [retrieve statistics](https://tokbox.com/developer/guides/client-observability/)  from both publishers and multiple subscribers, including sender-side statistics.

The Vonage Video SDK provides calls to access real-time network and media statistics in a video session. These calls report detailed stream quality metrics—such as packet loss, data received, and bandwidth—and can be used on any publisher or subscribed stream.

### Key Features Implemented

1.  **Multi-subscriber support**  
    The app tracks each subscriber individually using a dictionary keyed by  `streamId`. Multiple subscriber views and their corresponding stats are maintained separately.

2.  **Subscriber stats (including sender stats) monitoring**  
    Subscriber stats are updated in real-time as network stats change. Each subscriber maintains separate  `video`  and  `audio`  metrics. The  `OTSenderStats`  object provides information about the outgoing connection from the publisher’s perspective.
3. **Publisher stats monitoring**  
    Similar to subscribers, publisher stats are collected via  `OTPublisherKitNetworkStatsDelegate`  callbacks and displayed in real-time.
    

## Setting up the statistics

The following steps are needed to implement the stats monitoring. These are also highlighted in the code sample within `VonageVideoManager`, along with specific usage example. 

### Step 1: Enable sender-side Statistics

Set the `senderStatsTrack` of the Publisher to `true` to start sending the statistics:

```swift
let settings = OTPublisherSettings()
settings.senderStatsTrack = true
let publisher = OTPublisher(delegate: self, settings: settings)
```

### Step 2: Enable Subscriber Stats
Set the `networkStatsDelegate` on each subscriber to receive callbacks with statistics:

```swift
subscriber.networkStatsDelegate = self
```
### Step 3: Conform to `OTSubscriberKitNetworkStatsDelegate`
Add conformance to this protocol to read stats when the callbacks get triggered:

```swift
extension VonageVideoManager: OTSubscriberKitNetworkStatsDelegate {

    func subscriber(_ subscriber: OTSubscriberKit,
                    videoNetworkStatsUpdated stats: OTSubscriberKitVideoNetworkStats) {
        ...
    }

    func subscriber(_ subscriber: OTSubscriberKit,
                    audioNetworkStatsUpdated stats: OTSubscriberKitAudioNetworkStats) {
        ...
    }
}
```

### Step 4: Enable Publisher Stats
Set the `networkStatsDelegate` on each subscriber to receive callbacks with statistics:

```swift
publisger.networkStatsDelegate = self
```
### Step 5: Conform to `OTPublisherKitNetworkStatsDelegate`
Add conformance to this protocol to read stats when the callbacks get triggered:

swift

```swift
extension VonageVideoManager: OTPublisherKitNetworkStatsDelegate {

    func publisher(_ publisher: OTPublisherKit,
                   videoNetworkStatsUpdated statsArray: [OTPublisherKitVideoNetworkStats]) {
        ...
    }

    func publisher(_ publisher: OTPublisherKit,
                   audioNetworkStatsUpdated statsArray: [OTPublisherKitAudioNetworkStats]) {
        ...
    }
}

```
