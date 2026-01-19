//
//  BasicVideoCapturer.swift
//  BasicVideoCapturer
//
//  Created by Artur Osiński on 15/01/2026.
//

import Foundation
import OpenTok

class BasicVideoCapturer: NSObject, OTVideoCapture {
    
    // MARK: - Constants
    private let kFramesPerSecond: Double = 15.0
    private let kImageWidth: UInt32 = 320
    private let kImageHeight: UInt32 = 240
    
    // MARK: - Properties
    
    /// The consumer provided by the Vonage SDK. We send generated frames here.
    var videoCaptureConsumer: OTVideoCaptureConsumer?
    var videoContentHint: OTVideoContentHint = .none
    
    private var captureStarted: Bool = false
    private var videoFormat: OTVideoFormat?
    
    /// Helper to calculate the next frame deadline
    private var timerInterval: DispatchTime {
        return DispatchTime.now() + Double(1.0 / kFramesPerSecond)
    }
    
    // MARK: - OTVideoCapture Protocol
    func initCapture() {
        let format = OTVideoFormat()
        format.pixelFormat = .ARGB
        format.bytesPerRow = [NSNumber(value: kImageWidth * 4)]
        format.imageHeight = kImageHeight
        format.imageWidth = kImageWidth
        
        self.videoFormat = format
    }
    
    func releaseCapture() {
        self.videoFormat = nil
    }
    
    func start() -> Int32 {
        self.captureStarted = true
        
        // Start the frame loop on a background queue
        DispatchQueue.global(qos: .background).asyncAfter(deadline: timerInterval) { [weak self] in
            self?.produceFrame()
        }
        
        return 0
    }
    
    func stop() -> Int32 {
        self.captureStarted = false
        return 0
    }
    
    func isCaptureStarted() -> Bool {
        return self.captureStarted
    }
    
    func captureSettings(_ videoFormat: OTVideoFormat) -> Int32 {
        // Settings are fixed in this basic example
        return 0
    }
    
    // MARK: - Private Generation Logic
    
    private func produceFrame() {
        guard let format = videoFormat else { return }
        
        // 1. Create a frame object
        let frame = OTVideoFrame(format: format)
        
        // 2. Allocate memory for the image buffer (Width * Height * 4 bytes for ARGB)
        let bufferSize = Int(kImageWidth * kImageHeight * 4)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        
        // 3. Fill buffer with random noise
        // Looping byte-by-byte for random noise effect
        for i in stride(from: 0, to: bufferSize, by: 4) {
            buffer[i]     = UInt8.random(in: 0...255) // A
            buffer[i + 1] = UInt8.random(in: 0...255) // R
            buffer[i + 2] = UInt8.random(in: 0...255) // G
            buffer[i + 3] = UInt8.random(in: 0...255) // B
        }
        
        // 4. Pass the buffer to the frame.
        // setPlanesWithPointers expects an array of pointers (Pointer to Pointer).
        // Since we have 1 plane, we pass the address of our buffer pointer.
        var planePointer: UnsafeMutablePointer<UInt8> = buffer
        withUnsafeMutablePointer(to: &planePointer) { pointerToPlanePointer in
            frame.setPlanesWithPointers(UnsafeMutableRawPointer(pointerToPlanePointer).assumingMemoryBound(to: UnsafeMutablePointer<UInt8>.self), numPlanes: 1)
        }
        
        // 5. Send frame to Vonage SDK
        videoCaptureConsumer?.consumeFrame(frame)
        
        // 6. Cleanup memory (Vonage SDK copies the data internally upon consumeFrame)
        buffer.deallocate()
        
        // 7. Schedule next frame
        if captureStarted {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: timerInterval) { [weak self] in
                self?.produceFrame()
            }
        }
    }
}
