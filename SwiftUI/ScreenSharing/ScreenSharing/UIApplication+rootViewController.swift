//
//  UIApplication+rootViewController.swift
//  ScreenSharing
//
//  Created by Artur Osiński on 28/01/2026.
//

import UIKit

extension UIApplication {
    var rootViewController: UIViewController? {
        self.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
