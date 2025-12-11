//
//  VonageVideoManager.swift
//  ClientObservability
//

import OpenTok
import SwiftUI

final class VonageVideoManager: NSObject, ObservableObject {
    
    // Replace with your Vonage Application ID
    let kAppId = ""
    // Replace with your generated session Id
    let kSessionId = ""
    // Replace with your generated token
    let kToken = ""
    
    private var session: OTSession?
    
    private lazy var publisher: OTPublisher? = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        settings.senderStatsTrack = true
        let publisher = OTPublisher(delegate: self, settings: settings)
        publisher?.networkStatsDelegate = self
        return publisher
    }()
    
    private var subscribers: [String: OTSubscriber] = [:]
    @Published var subscriberViews: [String: UIView] = [:]
    @Published var pubView: UIView?
    
    @Published var publisherStats: [String: [String: [String]]] = [:]
    @Published var subscriberStats: [String: [String: [String]]] = [:]
    
    public func setup() {
        doConnect()
    }
    
    private func doConnect() {
        session = OTSession(applicationId: kAppId, sessionId: kSessionId, delegate: self)
        if session == nil {
            fatalError("Check your credentials and try again (kAppId, kSessionId, kToken)")
        }
        var error: OTError?
        defer {
            processError(error)
        }
        session?.connect(withToken: kToken, error: &error)
    }

    private func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            if let error {
                processError(error)
            }
        }
        let newSubscriber = OTSubscriber(stream: stream, delegate: self)
        newSubscriber?.networkStatsDelegate = self
        session?.subscribe(newSubscriber!, error: &error)
        
        if error == nil {
            subscribers[stream.streamId] = newSubscriber
        }
    }
    
    private func cleanupSubscriber(streamId: String) {
        guard let subscriber = self.subscribers[streamId] else { return }

        // Unsubscribe from session
        var error: OTError?
        session?.unsubscribe(subscriber, error: &error)
        if let error {
            print("Error unsubscribing: \(error)")
        }
        
        self.subscriberViews.removeValue(forKey: streamId)
        self.subscribers.removeValue(forKey: streamId)
        self.subscriberStats.removeValue(forKey: streamId)
    }
    
    private func cleanupPublisher() {
        DispatchQueue.main.async {
            self.pubView = nil
        }
    }
    
    private func processError(_ error: OTError?) {
        print("Got error \(String(describing: error))")
    }
}

extension VonageVideoManager: OTSessionDelegate {

    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        var error: OTError?
        defer {
            processError(error)
        }
        
        guard let publisher else {
            return
        }
        session.publish(publisher, error: &error)
        
        if let view = publisher.view {
            DispatchQueue.main.async {
                self.pubView = view
            }
        }
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        doSubscribe(stream)
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        cleanupSubscriber(streamId: stream.streamId)
    }
}

extension VonageVideoManager: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print("Publishing")
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        cleanupPublisher()
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

extension VonageVideoManager: OTSubscriberDelegate {
    
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        print("Subscriber connected: \(subscriberKit.stream?.streamId ?? "nil")")
        
        guard let subscriber = subscriberKit as? OTSubscriber,
              let streamId = subscriber.stream?.streamId,
              let view = subscriber.view else { return }

        DispatchQueue.main.async {
            self.subscriberViews[streamId] = view
        }
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
}

extension VonageVideoManager: OTPublisherKitNetworkStatsDelegate {

    func publisher(_ publisher: OTPublisherKit, videoNetworkStatsUpdated statsArray: [OTPublisherKitVideoNetworkStats]) {
        let publisherId = publisher.stream?.streamId ?? "nil"
        var lines: [String] = []

        for (index, stats) in statsArray.enumerated() {
            let line = """
            [Video Stats \(index)]
            connectionId: \(stats.connectionId)
            subscriberId: \(stats.subscriberId)
            videoPacketsSent: \(stats.videoPacketsSent)
            videoPacketsLost: \(stats.videoPacketsLost)
            videoBytesSent: \(stats.videoBytesSent)
            timestamp: \(stats.timestamp)
            startTime: \(stats.startTime)
            """
            print(line)
            lines.append(line)
        }

        if publisherStats[publisherId] == nil {
            publisherStats[publisherId] = ["video": [], "audio": []]
        }
        publisherStats[publisherId]?["video"] = lines
    }

    func publisher(_ publisher: OTPublisherKit, audioNetworkStatsUpdated statsArray: [OTPublisherKitAudioNetworkStats]) {
        let publisherId = publisher.stream?.streamId ?? "nil"
        var lines: [String] = []

        for (index, stats) in statsArray.enumerated() {
            let line = """
            [Audio Stats \(index)]
            connectionId: \(stats.connectionId)
            subscriberId: \(stats.subscriberId)
            audioPacketsSent: \(stats.audioPacketsSent)
            audioPacketsLost: \(stats.audioPacketsLost)
            audioBytesSent: \(stats.audioBytesSent)
            timestamp: \(stats.timestamp)
            startTime: \(stats.startTime)
            """
            print(line)
            lines.append(line)
        }

        if publisherStats[publisherId] == nil {
            publisherStats[publisherId] = ["video": [], "audio": []]
        }
        publisherStats[publisherId]?["audio"] = lines
    }
}

extension VonageVideoManager: OTSubscriberKitNetworkStatsDelegate {

    func subscriber(_ subscriber: OTSubscriberKit, videoNetworkStatsUpdated stats: OTSubscriberKitVideoNetworkStats) {
        guard let streamId = subscriber.stream?.streamId, subscribers[streamId] != nil else { return }
        var lines: [String] = []

        var log = """
        videoPacketsReceived: \(stats.videoPacketsReceived)
        videoPacketsLost: \(stats.videoPacketsLost)
        videoBytesReceived: \(stats.videoBytesReceived)
        timestamp: \(stats.timestamp)
        """

        if let senderStats = stats.senderStats {
            log += """
            
            ── Sender Stats (Video) ──
            connectionMaxAllocatedBitrate: \(senderStats.connectionMaxAllocatedBitrate)
            connectionEstimatedBandwidth: \(senderStats.connectionEstimatedBandwidth)
            """
        }

        print("[Subscriber Video Stats] subscriberId: \(streamId)\n\(log)")
        lines.append(log)

        if subscriberStats[streamId] == nil {
            subscriberStats[streamId] = ["video": [], "audio": []]
        }
        subscriberStats[streamId]?["video"] = lines
    }

    func subscriber(_ subscriber: OTSubscriberKit, audioNetworkStatsUpdated stats: OTSubscriberKitAudioNetworkStats) {
        guard let streamId = subscriber.stream?.streamId, subscribers[streamId] != nil else { return }
        var lines: [String] = []

        var log = """
        audioPacketsReceived: \(stats.audioPacketsReceived)
        audioPacketsLost: \(stats.audioPacketsLost)
        audioBytesReceived: \(stats.audioBytesReceived)
        timestamp: \(stats.timestamp)
        """

        if let senderStats = stats.senderStats {
            log += """
            
            ── Sender Stats (Audio) ──
            connectionMaxAllocatedBitrate: \(senderStats.connectionMaxAllocatedBitrate)
            connectionEstimatedBandwidth: \(senderStats.connectionEstimatedBandwidth)
            """
        }

        print("[Subscriber Audio Stats] subscriberId: \(streamId)\n\(log)")
        lines.append(log)

        if subscriberStats[streamId] == nil {
            subscriberStats[streamId] = ["video": [], "audio": []]
        }
        subscriberStats[streamId]?["audio"] = lines
    }
}
