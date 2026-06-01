import SwiftUI
import UIKit
import AVFoundation

struct SubscriberVideoView: UIViewRepresentable {
    @ObservedObject var manager: VonageVideoManager
    let size: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        context.coordinator.containerView = containerView
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let displayLayer = manager.videoRender.bufferDisplayLayer
        let frame = CGRect(origin: .zero, size: size)

        if displayLayer.superlayer !== uiView.layer {
            displayLayer.removeFromSuperlayer()
            displayLayer.frame = frame
            displayLayer.videoGravity = .resizeAspect
            uiView.layer.addSublayer(displayLayer)
        } else {
            displayLayer.frame = frame
        }

        guard !context.coordinator.didConfigurePictureInPicture else { return }
        context.coordinator.didConfigurePictureInPicture = true
        manager.configurePictureInPicture(with: uiView, videoFrame: frame)
    }

    final class Coordinator {
        var containerView: UIView?
        var didConfigurePictureInPicture = false
    }
}
