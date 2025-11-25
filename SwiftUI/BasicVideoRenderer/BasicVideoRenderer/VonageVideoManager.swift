//
//  VonageVideoManager.swift
//  BasicVideoRenderer
//
//  Created by Artur Osiński on 31/10/2025.
//

import OpenTok
import SwiftUI

final class VonageVideoManager: NSObject, ObservableObject {
    
    // *** Fill the following variables using your own Project info  ***
    // *** https://developer.vonage.com/en/video/getting-started     ***
    // Replace with your Vonage application Id
    let kAppId = ""
    // Replace with your generated session Id
    let kSessionId = ""
    // Replace with your generated token
    let kToken = ""
    
    let renderer = CustomVideoRender()
    
    private lazy var session: OTSession? = {
        OTSession(applicationId: kAppId, sessionId: kSessionId, delegate: self)
    }()
    
    private lazy var publisher: OTPublisher? = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)
    }()
    
    private var subscriber: OTSubscriber?
    
    @Published var pubView: AnyView?
    @Published var subView: AnyView?
    
    public func setup() {
        doConnect()
    }
    
    private func doConnect() {
        var error: OTError?
        defer {
            processError(error)
        }
        session?.connect(withToken: kToken, error: &error)
    }
    
    private func doPublish() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        // Publish
        guard let publisher else { return }
        publisher.videoRender = renderer
        session?.publish(publisher, error: &error)
        
        
        // Setup view
        guard let pubView = publisher.view else { return }
        
        pubView.frame = CGRect(x: 0, y: 0, width: 250, height: 250)
        renderer.view.frame = CGRect(x: 0, y: 0, width: 250, height: 250)
        pubView.addSubview(renderer.view)
        
        DispatchQueue.main.async {
            self.pubView = AnyView(Wrap(pubView))
        }
    }
    
    private func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            processError(error)
            
        }
        subscriber = OTSubscriber(stream: stream, delegate: self)
        guard let subscriber else { return }
        session?.subscribe(subscriber, error: &error)
    }
    
    private func cleanupSubscriber() {
        DispatchQueue.main.async {
            self.subView = nil
        }
    }
    
    private func cleanupPublisher() {
        DispatchQueue.main.async {
            self.pubView = nil
        }
    }
    
    private func processError(_ error: OTError?) {
        guard let error else { return }
        print(error)
    }
}

extension VonageVideoManager: OTSessionDelegate {
    
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
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
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
}

extension VonageVideoManager: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print("Publishing")
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        cleanupPublisher()
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

extension VonageVideoManager: OTSubscriberDelegate {
    
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        guard let view = self.subscriber?.view else { return }
        subView = AnyView(Wrap(view))
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
}
