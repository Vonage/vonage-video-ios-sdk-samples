import AVKit
import OpenTok
import SwiftUI
import UIKit
import Combine

final class VonageVideoManager: NSObject, ObservableObject {
    static let widgetRatio: CGFloat = 1.333

    // *** Fill using your Vonage Video project: https://dashboard.vonage.com/ ***
    // Replace with your Vonage Application ID
    let kAppId = ""
    // Replace with your generated session ID
    let kSessionId = ""
    // Replace with your generated token
    let kToken = ""

    let videoRender = ExampleVideoRender()
    private let sampleBufferVideoCallView = SampleBufferVideoCallView()

    private var session: OTSession?
    private var subscriber: OTSubscriber?
    private var pipController: AVPictureInPictureController?

    @Published var isSubscriberConnected = false
    @Published var canStartPictureInPicture = false
    @Published var showError = false
    @Published var errorMessage: String?

    func setup() {
        doConnect()
    }

    func configurePictureInPicture(with sourceView: UIView, videoFrame: CGRect) {
        guard pipController == nil else { return }
        print("Configuring Picture in Picture")

        videoRender.pipBufferDisplayLayer = sampleBufferVideoCallView.sampleBufferDisplayLayer
        videoRender.pipBufferDisplayLayer?.frame = videoFrame

        let pipVideoCallViewController = AVPictureInPictureVideoCallViewController()
        pipVideoCallViewController.preferredContentSize = CGSize(width: 640, height: 480)
        pipVideoCallViewController.view.addSubview(sampleBufferVideoCallView)

        sampleBufferVideoCallView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sampleBufferVideoCallView.leadingAnchor.constraint(equalTo: pipVideoCallViewController.view.leadingAnchor),
            sampleBufferVideoCallView.trailingAnchor.constraint(equalTo: pipVideoCallViewController.view.trailingAnchor),
            sampleBufferVideoCallView.topAnchor.constraint(equalTo: pipVideoCallViewController.view.topAnchor),
            sampleBufferVideoCallView.bottomAnchor.constraint(equalTo: pipVideoCallViewController.view.bottomAnchor)
        ])

        sampleBufferVideoCallView.bounds = pipVideoCallViewController.view.frame

        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: pipVideoCallViewController
        )

        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        pipController?.delegate = self
        updatePictureInPictureAvailability()
    }

    private func updatePictureInPictureAvailability() {
        DispatchQueue.main.async {
            let isPossible = self.pipController?.isPictureInPicturePossible ?? false
            self.canStartPictureInPicture = isPossible
            print("PiP supported:", AVPictureInPictureController.isPictureInPictureSupported())
            print("PiP possible:", isPossible)
        }
    }

    func startPictureInPicture() {
        pipController?.startPictureInPicture()
    }

    private func doConnect() {
        session = OTSession(applicationId: kAppId, sessionId: kSessionId, delegate: self)
        var error: OTError?
        defer {
            processError(error)
        }
        session?.connect(withToken: kToken, error: &error)
    }

    private func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            processError(error)
        }

        subscriber = OTSubscriber(stream: stream, delegate: self)
        subscriber?.videoRender = videoRender
        session?.subscribe(subscriber!, error: &error)

        NotificationCenter.default.removeObserver(
            subscriber,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        DispatchQueue.main.async {
            self.isSubscriberConnected = true
        }
    }

    private func cleanupSubscriber() {
        DispatchQueue.main.async {
            self.isSubscriberConnected = false
            self.canStartPictureInPicture = false
        }
        pipController = nil
        subscriber = nil
    }

    private func processError(_ error: OTError?) {
        guard let error else { return }
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
}

extension VonageVideoManager: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
    }

    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }

    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        if subscriber == nil {
            doSubscribe(stream)
        }
    }

    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }

    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
        processError(error)
    }
}

extension VonageVideoManager: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        print("Subscriber connected to stream")
    }

    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
        processError(error)
    }

    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {}
}

extension VonageVideoManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerIsPictureInPicturePossibleDidChange(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        updatePictureInPictureAvailability()
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("\(#function)")
        print("pip error: \(error)")
    }

    func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        print("\(#function)")
    }

    func pictureInPictureControllerWillStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        print("\(#function)")
    }
}
