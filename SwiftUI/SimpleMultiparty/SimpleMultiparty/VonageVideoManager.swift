//
//  VonageVideoManager.swift
//  SimpleMultiparty
//
//  Created by Artur Osiński on 28/05/2026.
//

import OpenTok
import SwiftUI
import Combine

final class VonageVideoManager: NSObject, ObservableObject {

    // *** Fill using your Vonage Video project: https://dashboard.vonage.com/ ***
    // Replace with your Vonage Application ID
    let kAppId = ""
    // Replace with your generated session ID
    let kSessionId = ""
    // Replace with your generated token
    let kToken = ""

    private static let maxSubscribers = 4

    private var session: OTSession?
    private var subscribers: [String: OTSubscriber] = [:]

    private lazy var publisher: OTPublisher? = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)
    }()

    @Published var userName = UIDevice.current.name
    @Published var pubView: UIView?
    @Published var participants: [RemoteParticipant] = []
    @Published var isMicMuted = false
    @Published var callControlsEnabled = false

    func setup() {
        doConnect()
    }

    func swapCamera() {
        guard let publisher else { return }
        publisher.cameraPosition = publisher.cameraPosition == .front ? .back : .front
    }

    func toggleMic() {
        guard let publisher else { return }
        publisher.publishAudio = !publisher.publishAudio
        isMicMuted = !publisher.publishAudio
    }

    func endCall() {
        var error: OTError?
        defer { processError(error) }
        session?.disconnect(&error)
    }

    func toggleSubscriberAudio(streamId: String) {
        guard let subscriber = subscribers[streamId] else { return }
        subscriber.subscribeToAudio = !subscriber.subscribeToAudio
        setParticipantAudio(streamId: streamId, subscribeToAudio: subscriber.subscribeToAudio)
    }

    func openDeveloperSite() {
        guard let url = URL(string: "https://developer.vonage.com/en/video/overview") else { return }
        UIApplication.shared.open(url)
    }

    private func doConnect() {
        session = OTSession(applicationId: kAppId, sessionId: kSessionId, delegate: self)
        if session == nil {
            fatalError("Check your credentials and try again (kAppId, kSessionId, kToken)")
        }
        var error: OTError?
        defer { processError(error) }
        session?.connect(withToken: kToken, error: &error)
    }

    private func doPublish() {
        var error: OTError?
        defer { processError(error) }

        guard let publisher, let session else { return }
        session.publish(publisher, error: &error)

        if let view = publisher.view {
            DispatchQueue.main.async {
                self.callControlsEnabled = true
                self.pubView = view
                self.isMicMuted = !publisher.publishAudio
            }
        }
    }

    private func doSubscribe(to stream: OTStream) {
        guard subscribers.count < Self.maxSubscribers else {
            print("Sorry this sample only supports up to \(Self.maxSubscribers) subscribers :)")
            return
        }

        var error: OTError?
        defer { processError(error) }

        guard let subscriber = OTSubscriber(stream: stream, delegate: self) else { return }
        subscribers[stream.streamId] = subscriber
        participants.append(RemoteParticipant(streamId: stream.streamId))
        session?.subscribe(subscriber, error: &error)
    }

    private func removeSubscriber(streamId: String) {
        subscribers[streamId]?.view?.removeFromSuperview()
        subscribers.removeValue(forKey: streamId)
        participants.removeAll { $0.streamId == streamId }
    }

    private func setParticipantAudio(streamId: String, subscribeToAudio: Bool) {
        guard let index = participants.firstIndex(where: { $0.streamId == streamId }) else { return }
        var participant = participants[index]
        participant.subscribeToAudio = subscribeToAudio
        participants[index] = participant
    }

    private func updateParticipantView(streamId: String, view: UIView?) {
        guard let index = participants.firstIndex(where: { $0.streamId == streamId }) else { return }
        var participant = participants[index]
        participant.view = view
        participants[index] = participant
    }

    private func processError(_ error: OTError?) {
        if let error {
            print("Got error \(error.localizedDescription)")
        }
    }
}

extension VonageVideoManager: OTSessionDelegate {

    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
    }

    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
        DispatchQueue.main.async {
            self.subscribers.removeAll()
            self.participants.removeAll()
            self.pubView = nil
            self.callControlsEnabled = false
        }
    }

    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        doSubscribe(to: stream)
    }

    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        DispatchQueue.main.async {
            self.removeSubscriber(streamId: stream.streamId)
        }
    }

    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
}

extension VonageVideoManager: OTPublisherDelegate {

    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
    }

    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        DispatchQueue.main.async {
            self.pubView = nil
            self.callControlsEnabled = false
        }
    }

    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

extension VonageVideoManager: OTSubscriberDelegate {

    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        print("Subscriber connected")
        guard let subscriber = subscriberKit as? OTSubscriber,
              let streamId = subscriber.stream?.streamId else { return }
        DispatchQueue.main.async {
            self.updateParticipantView(streamId: streamId, view: subscriber.view)
        }
    }

    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }

    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
    }
}
