//
//  CustomAudioDriverApp.swift
//  CustomAudioDriver
//
//  Created by Artur Osiński on 08/11/2025.
//

import SwiftUI

@main
struct CustomAudioDriverApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(manager: VonageVideoManager())
        }
    }
}
