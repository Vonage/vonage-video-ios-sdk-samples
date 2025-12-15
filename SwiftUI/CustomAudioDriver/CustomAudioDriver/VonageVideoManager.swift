//
//  VonageVideoManager.swift
//  CustomAudioDriver
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
    let kSessionId = ""
    let kToken = ""
    
    private var myAudioDevice: AudioDeviceRingtone?
    private var reconnectPlease: Bool = false
    
    private lazy var session: OTSession? = {
        let session = OTSession(applicationId: kAppId, sessionId: kSessionId, delegate: self)
        guard session != nil else {
            fatalError("Make sure you fill in your kAppId, kSessionId, and kToken")
        }
        return session
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
        if let path = Bundle.main.path(forResource: "bananaphone", ofType: "mp3") {
            myAudioDevice = AudioDeviceRingtone(ringtone: URL(fileURLWithPath: path))
            OTAudioDeviceManager.setAudioDevice(myAudioDevice)
        }
        doConnect()
    }

    private func resetSession() {
        if let session = session {
            session.disconnect(nil)
            reconnectPlease = true
            return
        }
        
        // Step 1: As the view comes into the foreground, initialize a new instance
        // of OTSession and begin the connection process.
        
        session = OTSession(applicationId: kAppId,
                           sessionId: kSessionId,
                           delegate: self)
        
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
        session?.publish(publisher, error: &error)
        
        
        // Setup view
        guard let pubView = publisher.view else { return }
        
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
        // Step 2: We have successfully connected, now instantiate a publisher and
        // begin pushing A/V streams.
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
        if subscriber != nil {
            cleanupSubscriber()
        }
        if reconnectPlease {
            reconnectPlease = false
            resetSession()
        }
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
    
    func session(_ session: OTSession, connectionCreated connection: OTConnection) {
        print("session connectionCreated (\(connection.connectionId))")
    }
    
    func session(_ session: OTSession, connectionDestroyed connection: OTConnection) {
        print("session connectionDestroyed (\(connection.connectionId))")
        if subscriber?.stream?.connection.connectionId == connection.connectionId {
            cleanupSubscriber()
        }
    }
}

extension VonageVideoManager: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print("Publishing")
        // play the ringtone for 10 seconds , it is fun...
        // doSubscribe method will stop it later
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.doSubscribe(stream)
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        print("publisher \(publisher) streamDestroyed \(stream)")
        
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
        
        cleanupPublisher()
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("publisher didFailWithError \(error)")
        cleanupPublisher()
    }
}

extension VonageVideoManager: OTSubscriberDelegate {
    
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        print("subscriberDidConnectToStream (\(subscriber?.stream?.connection.connectionId ?? ""))")
        
        // Stop ringtone from playing, as the subscriber will connect shortly
        myAudioDevice?.stopRingtone()
        guard let view = self.subscriber?.view else { return }
        subView = AnyView(Wrap(view))
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
    
    func subscriberDidDisconnect(fromStream subscriberKit: OTSubscriberKit) {
        print("subscriberDidDisconnectFromStream \(subscriberKit)")
        cleanupSubscriber()
    }
}
