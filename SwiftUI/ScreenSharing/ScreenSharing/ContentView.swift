//
//  ContentView.swift
//  BasicVideoCapturer
//
//  Created by Artur Osiński on 16/01/2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var videoManager = VonageVideoManager()
    
    var body: some View {
        VStack {
            Text(videoManager.timeStamp)
            Wrap(videoManager.screensharingView)
                .frame(width: 200, height: 200, alignment: .center)
                .cornerRadius(5.0)
            
//            videoManager.pubView.map { view in
//                Wrap(view)
//                    .frame(width: 200, height: 200, alignment: .center)
//                    .cornerRadius(5.0)
//            }
//            videoManager.subView.map { view in
//                Wrap(view)
//                    .frame(width: 200, height: 200, alignment: .center)
//                    .cornerRadius(5.0)
//            }
        }
        .task {
            videoManager.setup()
        }
    }
}
#Preview {
    ContentView()
}
