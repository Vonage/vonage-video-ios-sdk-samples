//
//  ContentView.swift
//  PictureInPicture
//
//  Created by Artur Osiński on 31/05/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var videoManager = VonageVideoManager()

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                if videoManager.isSubscriberConnected {
                    SubscriberVideoView(
                        manager: videoManager,
                        size: videoSize(for: geometry.size.width)
                    )
                    .frame(width: geometry.size.width, height: videoSize(for: geometry.size.width).height)
                } else {
                    waitingView
                        .frame(width: geometry.size.width, height: videoSize(for: geometry.size.width).height)
                }

                Button("Start PiP") {
                    videoManager.startPictureInPicture()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!videoManager.canStartPictureInPicture)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding()
        .task {
            videoManager.setup()
        }
        .alert("Error", isPresented: $videoManager.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(videoManager.errorMessage ?? "An unknown error occurred.")
        }
    }

    private var waitingView: some View {
        ZStack {
            Color(.systemBackground)
            Text("Waiting for Remote Stream...")
                .foregroundStyle(.secondary)
        }
    }

    private func videoSize(for width: CGFloat) -> CGSize {
        CGSize(width: width, height: width / VonageVideoManager.widgetRatio)
    }
}
