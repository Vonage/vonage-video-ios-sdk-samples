import SwiftUI
import UIKit
import AVFoundation

final class VideoContainerView: UIView {
    var onEnterWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onEnterWindow?()
        }
    }
}

struct SubscriberVideoView: UIViewRepresentable {
    @ObservedObject var manager: VonageVideoManager
    let size: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> VideoContainerView {
        let containerView = VideoContainerView()
        containerView.backgroundColor = .black
        let coordinator = context.coordinator
        containerView.onEnterWindow = { [weak containerView] in
            guard let containerView else { return }
            coordinator.configurePictureInPictureIfNeeded(for: containerView)
        }
        return containerView
    }

    func updateUIView(_ uiView: VideoContainerView, context: Context) {
        context.coordinator.manager = manager
        context.coordinator.videoSize = size

        let frame = CGRect(origin: .zero, size: size)
        let displayLayer = manager.videoRender.bufferDisplayLayer

        if displayLayer.superlayer !== uiView.layer {
            displayLayer.removeFromSuperlayer()
            displayLayer.frame = frame
            displayLayer.videoGravity = .resizeAspect
            uiView.layer.addSublayer(displayLayer)
        } else {
            displayLayer.frame = frame
        }

        context.coordinator.configurePictureInPictureIfNeeded(for: uiView)
    }

    final class Coordinator {
        weak var manager: VonageVideoManager?
        var videoSize: CGSize = .zero
        var didConfigurePictureInPicture = false

        func configurePictureInPictureIfNeeded(for view: UIView) {
            guard !didConfigurePictureInPicture,
                  let manager,
                  view.window != nil else { return }

            didConfigurePictureInPicture = true
            let frame = CGRect(origin: .zero, size: videoSize)
            manager.configurePictureInPicture(with: view, videoFrame: frame)
        }
    }
}
