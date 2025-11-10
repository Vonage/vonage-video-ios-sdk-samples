//
//  CustomVideoRender.swift
//  BasicVideoRenderer
//
//  Created by Artur Osiński on 31/10/2025.
//

import OpenTok
import UIKit

final class CustomVideoRender: NSObject, OTVideoRender {
    let view = CustomRenderView(frame: .zero)
    
    func renderVideoFrame(_ frame: OTVideoFrame) {
        view.renderVideoFrame(frame)
    }
}
