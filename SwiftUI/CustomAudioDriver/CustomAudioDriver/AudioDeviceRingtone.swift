//
//  AudioDeviceRingtone.swift
//  CustomAudioDriver
//
//  Created by Artur Osiński on 31/10/2025.
//

import Foundation
import AVFoundation
import AudioToolbox
import OpenTok

class AudioDeviceRingtone: OTDefaultAudioDevice, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var deferredCallbacks: [String] = []
    private var vibratesWithRingtone: Bool = false
    private var vibrateTimer: Timer?
    private let vibrateFrequencySeconds: TimeInterval = 1.0
    private var ringtoneURL: URL?
    
    @available(*, unavailable, message: "init not available, use initWithRingtone:")
    override init() {
        fatalError("init not available, use initWithRingtone:")
    }
    
    init(ringtone url: URL) {
        super.init()
        ringtoneURL = url
    }
    
    // Immediately stops the ringtone and allows OpenTok audio calls to flow
    func stopRingtone() {
        // Stop Audio
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Stop vibration
        vibrateTimer?.invalidate()
        vibrateTimer = nil
        
        _ = startCapture()
        _ = startRendering()
        // Allow deferred audio callback calls to flow
        flushDeferredCallbacks()
    }
    
    // Make sure audio is initialized before you call this method.
    // Else publisher's will timeout with error.
    func playRingtone(from url: URL) {
        // 1. Pause audio
        // These methods stop the Vonage audio unit from accessing the hardware
        _ = stopCapture()
        _ = stopRendering()
        // 2. Stop & replace existing audio player
        if let player = audioPlayer {
            player.stop()
            audioPlayer = nil
        }
        
        // 3. Initialize the AVAudioPlayer
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            
            // Loop indefinitely
            audioPlayer?.numberOfLoops = -1
            
            // 4. Setup Vibration Timer
            if vibratesWithRingtone {
                vibrateTimer = Timer.scheduledTimer(timeInterval: vibrateFrequencySeconds,
                                                    target: self,
                                                    selector: #selector(buzz(_:)),
                                                    userInfo: nil,
                                                    repeats: true)
            }
            
            // 5. Play the audio
            audioPlayer?.play()
        } catch {
            print("Ringtone audio player initialization failure \(error)")
            audioPlayer = nil
        }
    }
    
    @objc private func buzz(_ timer: Timer) {
        if vibratesWithRingtone {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    /**
     * Private method: Can't always do as requested immediately. Defer incoming
     * callbacks from OTAudioBus until we aren't playing anything back
     */
    private func enqueueDeferredCallback(_ callback: Selector) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        let selectorString = NSStringFromSelector(callback)
        deferredCallbacks.append(selectorString)
    }
    
    private func flushDeferredCallbacks() {
        while !deferredCallbacks.isEmpty {
            let selectorString = deferredCallbacks[0]
            print("performing deferred callback \(selectorString)")
            let callback = NSSelectorFromString(selectorString)
            
            perform(callback)
            
            deferredCallbacks.removeFirst()
        }
    }
    
    // MARK: - OTDefaultAudioDevice overrides
    
    override func startRendering() -> Bool {
        if audioPlayer != nil {
            enqueueDeferredCallback(#selector(AudioDeviceRingtone.startRendering))
            return true
        } else {
            return super.startRendering()
        }
    }
    
    override func stopRendering() -> Bool {
        if audioPlayer != nil {
            enqueueDeferredCallback(#selector(AudioDeviceRingtone.stopRendering))
            return true
        } else {
            return super.stopRendering()
        }
    }
    
    private static var onceToken: Int = 0
    
    override func startCapture() -> Bool {
        if audioPlayer != nil {
            enqueueDeferredCallback(#selector(AudioDeviceRingtone.startCapture))
            return true
        } else {
            let parentStartCapture = super.startCapture()
            
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            
            if AudioDeviceRingtone.onceToken == 0 {
                AudioDeviceRingtone.onceToken = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let url = self.ringtoneURL {
                        self.playRingtone(from: url)
                    }
                }
            }
            
            return parentStartCapture
        }
    }
    
    override func stopCapture() -> Bool {
        if audioPlayer != nil {
            enqueueDeferredCallback(#selector(AudioDeviceRingtone.stopCapture))
            return true
        } else {
            return super.stopCapture()
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("audioPlayerDidFinishPlaying success=\(flag)")
        stopRingtone()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("audioPlayerDecodeErrorDidOccur \(error?.localizedDescription ?? "unknown error")")
        stopRingtone()
    }
}

