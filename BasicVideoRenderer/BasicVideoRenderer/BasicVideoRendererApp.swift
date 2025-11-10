//
//  BasicVideoRendererApp.swift
//  BasicVideoRenderer
//
//  Created by Artur Osiński on 08/11/2025.
//

import SwiftUI

@main
struct BasicVideoRendererApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(manager: VonageVideoManager())
        }
    }
}
