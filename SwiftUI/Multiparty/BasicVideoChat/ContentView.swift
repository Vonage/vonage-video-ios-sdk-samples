//
//  ContentView.swift
//  BasicVideoChat
//
//  Created by Artur Osiński on 02/12/2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var videoManager = VonageVideoManager()
    
    var body: some View {
        VStack {
            videoManager.pubView.flatMap { view in
                Wrap(view)
                    .frame(width: 200, height: 200, alignment: .center)
            }.cornerRadius(5.0)
            videoManager.subView.flatMap { view in
                Wrap(view)
                    .frame(width: 200, height: 200, alignment: .center)
            }.cornerRadius(5.0)
        }
        .task {
            videoManager.setup()
        }
    }
}
#Preview {
    ContentView()
}
