//
//  VonageVideoManager.swift
//  BasicVideoChat
//
//  Created by Artur Osiński on 31/10/2025.
//

import OpenTok
import SwiftUI
import Combine

final class VonageVideoManager: NSObject, ObservableObject {
    
    // Replace with your Vonage Application ID
    let kAppId = "67b7059b-142b-4630-ab25-714e2ccd04fa"
    // Replace with your generated session Id
    let kSessionId = "1_MX42N2I3MDU5Yi0xNDJiLTQ2MzAtYWIyNS03MTRlMmNjZDA0ZmF-fjE3Njg3NjY0NjcxMzJ-S0V2SSt4NHFzVUlnOExsVHdJbDVWb2Nzfn5-"
    // Replace with your generated token
    let kToken = "eyJhbGciOiJSUzI1NiIsImprdSI6Imh0dHBzOi8vYW51YmlzLWNlcnRzLWMxLWV1dzEucHJvZC52MS52b25hZ2VuZXR3b3Jrcy5uZXQvandrcyIsImtpZCI6IkNOPVZvbmFnZSAxdmFwaWd3IEludGVybmFsIENBOjo5Mjk0NDE2NDY2MDQ3MDkxNjg2ODM2NzE2NDUyNzgyODQyOTU5NyIsInR5cCI6IkpXVCIsIng1dSI6Imh0dHBzOi8vYW51YmlzLWNlcnRzLWMxLWV1dzEucHJvZC52MS52b25hZ2VuZXR3b3Jrcy5uZXQvdjEvY2VydHMvODJhMmI0OWQzZDA0OWVhNjFmMWNkNmVmMjJkNWE5ZDUifQ.eyJwcmluY2lwYWwiOnsiYWNsIjp7InBhdGhzIjp7Ii8qKiI6e319fSwidmlhbUlkIjp7ImVtYWlsIjoiYXJ0dXIub3NpbnNraUB2b25hZ2UuY29tIiwiZ2l2ZW5fbmFtZSI6IkFydCIsImZhbWlseV9uYW1lIjoiT3NpIiwicGhvbmVfbnVtYmVyIjoiNDg2MDE3OTkyNjEiLCJwaG9uZV9udW1iZXJfY291bnRyeSI6IlBMIiwib3JnYW5pemF0aW9uX2lkIjoiOTgxNDE0YTktMmZkNC00ZDE4LWIzN2ItNDhlMWQ5Y2EwMDdiIiwiYXV0aGVudGljYXRpb25NZXRob2RzIjpbeyJjb21wbGV0ZWRfYXQiOiIyMDI2LTAxLTE4VDE5OjU5OjI3LjE5OTMxNDAyNVoiLCJtZXRob2QiOiJpbnRlcm5hbCJ9XSwiaXBSaXNrIjp7ImlzX3Byb3h5Ijp0cnVlLCJyaXNrX2xldmVsIjo4NH0sInRva2VuVHlwZSI6InZpYW0iLCJhdWQiOiJwb3J0dW51cy5pZHAudm9uYWdlLmNvbSIsImV4cCI6MTc2ODc3NjY3OCwianRpIjoiMTRlNjhhNzUtZGE1OC00NTI0LTkxZmYtMTljOWM4NTEwODQ4IiwiaWF0IjoxNzY4Nzc2Mzc4LCJpc3MiOiJWSUFNLUlBUCIsIm5iZiI6MTc2ODc3NjM2Mywic3ViIjoiMmQ1OWUwYjQtNmY0Mi00NmEzLThmNDYtNWRjODM5Y2ViNTc2In19LCJmZWRlcmF0ZWRBc3NlcnRpb25zIjp7InZpZGVvLWFwaSI6W3siYXBpS2V5IjoiNTUxOTEwZWYiLCJhcHBsaWNhdGlvbklkIjoiNjdiNzA1OWItMTQyYi00NjMwLWFiMjUtNzE0ZTJjY2QwNGZhIiwibWFzdGVyQWNjb3VudElkIjoiNTUxOTEwZWYiLCJleHRyYUNvbmZpZyI6eyJ2aWRlby1hcGkiOnsiaW5pdGlhbF9sYXlvdXRfY2xhc3NfbGlzdCI6IiIsInJvbGUiOiJtb2RlcmF0b3IiLCJzY29wZSI6InNlc3Npb24uY29ubmVjdCIsInNlc3Npb25faWQiOiIxX01YNDJOMkkzTURVNVlpMHhOREppTFRRMk16QXRZV0l5TlMwM01UUmxNbU5qWkRBMFptRi1makUzTmpnM05qWTBOamN4TXpKLVMwVjJTU3Q0TkhGelZVbG5PRXhzVkhkSmJEVldiMk56Zm41LSJ9fX1dfSwiYXVkIjoicG9ydHVudXMuaWRwLnZvbmFnZS5jb20iLCJleHAiOjE3Njg3NzgxNzgsImp0aSI6ImU4ZGE5ZjZlLWJkMzUtNGQxZS1iYzM2LTgyMTVjZDk0ZWYxOSIsImlhdCI6MTc2ODc3NjM3OCwiaXNzIjoiVklBTS1JQVAiLCJuYmYiOjE3Njg3NzYzNjMsInN1YiI6IjJkNTllMGI0LTZmNDItNDZhMy04ZjQ2LTVkYzgzOWNlYjU3NiJ9.poC0iG-MDAa1X0Q9Id1d8EFkkKS91ggecCeLIub8Dgf-lo5x3OP-MvjYIPpcZQEuVbyHZ88w-lbYlzV1K5HX5Ix3ld45SSzG4io05YadzT5mbZ7xbu4jD3z-9f3KPmGmwSNQW4HAxkMM_EkjRM-gSmkYIj_RVa4yCFBOkHLh4Kv2DKTbCzLlgcEnvoJeEB7Hh8c-BebpJAxEXOCrUUZZXfn7N6U2nJdSLITE0hMzK30cFdXvF9D4NnprGhMsvn081bmKXzcb_fsFdIHg6fRPbqhB-MvCA5dtaz-34MnbrEcvaByj6FENDTEPEdpy1fyaasi0fwrfBse9_Kh_lXsc4A"
    
    private var session: OTSession?
    
    private lazy var publisher: OTPublisher? = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)
    }()
    
    private var subscriber: OTSubscriber?
    
    @Published var pubView: UIView?
    @Published var subView: UIView?
    
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
        publisher.videoCapture = BasicVideoCapturer()
//        publisher.videoCapture = BasicVideoCapturerCamera(preset: .cif352x288, desiredFrameRate: 30)
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
        print("The subscriber did connect to the stream.")
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
