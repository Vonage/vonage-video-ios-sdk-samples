//
//  VonageVideoManager.swift
//  BasicVideoChat
//
//  Created by Artur Osiński on 02/12/2025.
//


//
//  VonageVideoManager.swift
//  testproj
//
//  Created by Artur Osiński on 31/10/2025.
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
    
    private lazy var session: OTSession? = {
        OTSession(applicationId: kAppId, sessionId: kSessionId, delegate:self)
    }()
    
    private lazy var publisher: OTPublisher? = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)
    }()
    
    private var subscriber: OTSubscriber?
    
    @Published var pubView: AnyView?
    @Published var subView: UIView?
//    @Published var error: OTErrorWrapper?
    
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
        
    }
    
    private func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            if let error {
                print(error)
            }
            
        }
        subscriber = OTSubscriber(stream: stream, delegate: self)
        session?.subscribe(subscriber!, error: &error)
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
        if let err = error {
            DispatchQueue.main.async {
                self.error = OTErrorWrapper(error: err.localizedDescription)
            }
        }
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
                self.pubView = AnyView(Wrap(view))
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
        if let view = subscriber?.view {
            DispatchQueue.main.async {
                self.subView = view
            }
        }
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
}
