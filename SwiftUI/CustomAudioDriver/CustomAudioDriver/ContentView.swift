//
//  ContentView.swift
//  CustomAudioDriver
//
//  Created by Artur Osiński on 08/11/2025.
//

import SwiftUI
import OpenTok

struct ContentView: View {
    @ObservedObject var manager: VonageVideoManager
    
    var body: some View {
        VStack {
            if let pubView = manager.pubView {
                pubView
                    .frame(width: 250, height: 250)
            }
            if let subView = manager.subView {
                subView
                    .frame(width: 250, height: 250)
            }
        }
        .padding()
        .task {
            manager.setup()
        }
    }
}
