//
//  ContentView.swift
//  SimpleMultiparty
//
//  Created by Artur Osiński on 28/05/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var videoManager = VonageVideoManager()

    private let toolbarBackground = Color(red: 0.16, green: 0.16, blue: 0.16)
    private let headerBackground = Color(white: 0.67)

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            subscriberArea
            controlBar
        }
        .background(Color.black)
        .task {
            videoManager.setup()
        }
    }

    private var headerBar: some View {
        ZStack {
            headerBackground
            Text(videoManager.userName)
                .foregroundStyle(.white)
            HStack {
                Button(action: videoManager.openDeveloperSite) {
                    Image("TB Bug-30")
                }
                .padding(.leading, 8)
                Spacer()
            }
        }
        .frame(height: 50)
    }

    private var subscriberArea: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                if videoManager.participants.isEmpty {
                    Text("Subscriber Area")
                        .font(.system(size: 19, weight: .regular, design: .default))
                        .italic()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let columns = [
                        GridItem(.flexible(), spacing: 0),
                        GridItem(.flexible(), spacing: 0),
                    ]
                    let cellWidth = geometry.size.width / 2
                    let cellHeight = geometry.size.height / 2

                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(videoManager.participants) { participant in
                            SubscriberCellView(
                                participant: participant,
                                onToggleAudio: {
                                    videoManager.toggleSubscriberAudio(streamId: participant.streamId)
                                }
                            )
                            .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                }

                if let pubView = videoManager.pubView {
                    Wrap(pubView)
                        .frame(
                            width: geometry.size.width / 4,
                            height: geometry.size.height / 6
                        )
                        .padding([.trailing, .bottom], 4)
                }
            }
        }
    }

    private var controlBar: some View {
        ZStack {
            toolbarBackground
            Button("End Call") {
                videoManager.endCall()
            }
            .disabled(!videoManager.callControlsEnabled)
            .foregroundStyle(.white)

            HStack {
                Button(action: videoManager.swapCamera) {
                    Image("camera_switch-33")
                }
                .disabled(!videoManager.callControlsEnabled)
                .padding(.leading, 8)

                Spacer()

                Button(action: videoManager.toggleMic) {
                    Image(videoManager.isMicMuted ? "mic_muted-24" : "mic-24")
                }
                .disabled(!videoManager.callControlsEnabled)
                .padding(.trailing, 8)
            }
        }
        .frame(height: 50)
    }
}

private struct SubscriberCellView: View {
    let participant: RemoteParticipant
    let onToggleAudio: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black

            if let view = participant.view {
                Wrap(view)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button(action: onToggleAudio) {
                Image(
                    participant.subscribeToAudio
                        ? "Subscriber-Speaker-35"
                        : "Subscriber-Speaker-Mute-35"
                )
                .resizable()
                .frame(width: 20, height: 20)
            }
            .padding(8)
        }
    }
}

#Preview {
    ContentView()
}
