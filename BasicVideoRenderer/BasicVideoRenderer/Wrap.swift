//
//  Wrap.swift
//  BasicVideoRenderer
//
//  Created by Artur Osiński on 31/10/2025.
//

import UIKit
import SwiftUI

struct Wrap: UIViewRepresentable {
    private let view: UIView
    
    init(_ view: UIView) {
        self.view = view
    }
    
    func makeUIView(context: Context) -> UIView {
        view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // protocol requirement
    }
}
