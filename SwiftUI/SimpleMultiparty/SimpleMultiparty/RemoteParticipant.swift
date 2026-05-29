//
//  RemoteParticipant.swift
//  SimpleMultiparty
//
//  Created by Artur Osiński on 23/05/2026.
//

import Foundation
import UIKit

struct RemoteParticipant: Identifiable, Equatable {
    let streamId: String
    var view: UIView?
    var subscribeToAudio: Bool = true

    var id: String { streamId }

    static func == (lhs: RemoteParticipant, rhs: RemoteParticipant) -> Bool {
        lhs.streamId == rhs.streamId
            && lhs.subscribeToAudio == rhs.subscribeToAudio
            && lhs.view === rhs.view
    }
}
