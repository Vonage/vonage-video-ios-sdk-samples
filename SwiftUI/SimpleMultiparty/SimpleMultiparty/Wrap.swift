//
//  Wrap.swift
//  SimpleMultiparty
//
//  Created by Artur Osiński on 28/05/2026.
//

import SwiftUI
import UIKit

struct Wrap: UIViewRepresentable {
    private let view: UIView

    init(_ view: UIView) {
        self.view = view
    }

    func makeUIView(context: Context) -> UIView { view }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
