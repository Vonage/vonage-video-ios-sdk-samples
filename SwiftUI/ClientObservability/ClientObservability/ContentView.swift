import SwiftUI

struct ContentView: View {
    @ObservedObject var videoManager = VonageVideoManager()
    
    var body: some View {
        TabView {
            // Video tab
            VStack(spacing: 20) {
                videoManager.pubView.flatMap { view in
                    Wrap(view)
                        .frame(width: 200, height: 200, alignment: .center)
                }.cornerRadius(5.0)
                
                ForEach(Array(videoManager.subscriberViews.keys), id: \.self) { streamId in
                    if let view = videoManager.subscriberViews[streamId] {
                        Wrap(view)
                            .frame(width: 200, height: 200, alignment: .center)
                            .cornerRadius(5.0)
                    }
                }
            }
            .tabItem {
                Label("Video", systemImage: "video")
            }
            
            // Stats tab
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Publisher stats panels
                    ForEach(Array(videoManager.publisherStats.keys), id: \.self) { pubId in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Publisher: \(pubId)").font(.headline)
                            
                            if let videoStats = videoManager.publisherStats[pubId]?["video"] {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Video Stats").font(.subheadline).bold()
                                    ForEach(videoStats, id: \.self) { line in
                                        Text(line).font(.caption2).monospaced()
                                    }
                                }
                            }
                            
                            if let audioStats = videoManager.publisherStats[pubId]?["audio"] {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Audio Stats").font(.subheadline).bold()
                                    ForEach(audioStats, id: \.self) { line in
                                        Text(line).font(.caption2).monospaced()
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Subscriber stats panels
                    ForEach(Array(videoManager.subscriberStats.keys), id: \.self) { streamId in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subscriber: \(streamId)").font(.headline)
                            
                            if let videoStats = videoManager.subscriberStats[streamId]?["video"] {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Video Stats").font(.subheadline).bold()
                                    ForEach(videoStats, id: \.self) { line in
                                        Text(line).font(.caption2).monospaced()
                                    }
                                }
                            }
                            
                            if let audioStats = videoManager.subscriberStats[streamId]?["audio"] {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Audio Stats").font(.subheadline).bold()
                                    ForEach(audioStats, id: \.self) { line in
                                        Text(line).font(.caption2).monospaced()
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                }
                .padding()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar")
            }
        }
        .task {
            videoManager.setup()
        }
    }
}
