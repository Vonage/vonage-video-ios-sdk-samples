//
//  BasicVideoCapturerCamera.swift
//  BasicVideoCapturer
//
//  Created by Artur Osiński on 18/01/2026.
//


import Foundation
import OpenTok
import AVFoundation
import UIKit

class BasicVideoCapturerCamera: NSObject, OTVideoCapture, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Properties
    
    var videoCaptureConsumer: OTVideoCaptureConsumer?
    var videoContentHint: OTVideoContentHint = .none
    
    private var captureStarted: Bool = false
    private var format: OTVideoFormat?
    private var captureSession: AVCaptureSession?
    private var inputDevice: AVCaptureDeviceInput?
    private var sessionPreset: AVCaptureSession.Preset
    private var imageWidth: Int = 0
    private var imageHeight: Int = 0
    private var desiredFrameRate: Int
    private let captureQueue: DispatchQueue

    // MARK: - Initialization
    
    init(preset: AVCaptureSession.Preset, desiredFrameRate: Int) {
        self.sessionPreset = preset
        self.desiredFrameRate = desiredFrameRate
        self.captureQueue = DispatchQueue(label: "com.vonage.BasicVideoCapturer")
        
        super.init()
        
        // Calculate dimensions based on preset
        let size = self.size(from: self.sessionPreset)
        self.imageWidth = Int(size.width)
        self.imageHeight = Int(size.height)
    }

    // MARK: - OTVideoCapture Protocol
    
    func initCapture() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // 1. Set Presets
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
        }
        
        // 2. Set Device Input
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Error creating video capture device")
            return
        }
        
        self.inputDevice = deviceInput
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        // 3. Set Output
        let outputDevice = AVCaptureVideoDataOutput()
        outputDevice.alwaysDiscardsLateVideoFrames = true
        
        // Use NV12 pixel format (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        outputDevice.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ]
        
        outputDevice.setSampleBufferDelegate(self, queue: captureQueue)
        
        if session.canAddOutput(outputDevice) {
            session.addOutput(outputDevice)
        }
        
        // 4. Set Frame Rate
        let bestFPS = self.bestFrameRate(for: videoDevice)
        do {
            try videoDevice.lockForConfiguration()
            // Create CMTime for 1/FPS
            let duration = CMTime(value: 1, timescale: CMTimeScale(bestFPS))
            videoDevice.activeVideoMinFrameDuration = duration
            videoDevice.activeVideoMaxFrameDuration = duration
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error locking configuration for frame rate: \(error)")
        }
        
        session.commitConfiguration()
        self.captureSession = session
        
        self.format = OTVideoFormat(nv12WithWidth: UInt32(imageWidth), height: UInt32(imageHeight))
    }
    
    func releaseCapture() {
        self.format = nil
        self.captureSession = nil
        self.inputDevice = nil
    }
    
    //
    //  returns:
    //  - a negative value for error
    //  - 0 value when all is OK
    //
    func start() -> Int32 {
        self.captureStarted = true
        self.captureSession?.startRunning()
        return 0
    }
    
    //
    //  returns:
    //  - a negative value for error
    //  - 0 value when all is OK
    //
    func stop() -> Int32 {
        self.captureStarted = false
        self.captureSession?.stopRunning()
        return 0
    }
    
    func isCaptureStarted() -> Bool {
        return self.captureStarted
    }
    
    //
    //  returns:
    //  - a negative value for error
    //  - 0 value when all is OK
    //
    func captureSettings(_ videoFormat: OTVideoFormat) -> Int32 {
        videoFormat.pixelFormat = .NV12
        videoFormat.imageWidth = UInt32(self.imageWidth)
        videoFormat.imageHeight = UInt32(self.imageHeight)
        return 0
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Frame dropped")
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard captureStarted, let format = self.format else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let frame = OTVideoFrame(format: format)
        
        let planeCount = CVPixelBufferGetPlaneCount(imageBuffer)
        let totalSize = CVPixelBufferGetDataSize(imageBuffer)
        
        // Allocate buffer to hold pixel data (Same as malloc in Obj-C)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalSize)
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        
        var planePointers = [UnsafeMutablePointer<UInt8>?]()
        var currentDestination = buffer
        
        for i in 0..<planeCount {
            guard let sourceBaseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i) else { continue }
            
            let planeSize = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i) * CVPixelBufferGetHeightOfPlane(imageBuffer, i)
            
            // Store the pointer to this plane
            planePointers.append(currentDestination)
            
            // Copy memory from CoreVideo buffer to our manual buffer
            // memcpy(dest, src, size)
            memcpy(currentDestination, sourceBaseAddress, planeSize)
            
            // Move pointer forward
            currentDestination += planeSize
        }
        
        if let device = self.inputDevice?.device {
             let minDuration = device.activeVideoMinFrameDuration
             // Calculate FPS from CMTime (timescale / value)
             frame.format?.estimatedFramesPerSecond = Double(minDuration.timescale) / Double(minDuration.value)
        }
        
        frame.format?.estimatedCaptureDelay = 100
        frame.orientation = self.currentDeviceOrientation()
        frame.timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        let nonOptionalPlanePointers = planePointers.compactMap { $0 }
        nonOptionalPlanePointers.withUnsafeBufferPointer { bufferPointer in
            if let baseAddress = bufferPointer.baseAddress {
                frame.setPlanesWithPointers(UnsafeMutablePointer(mutating: baseAddress), numPlanes: Int32(planeCount))
            }
        }
        
        videoCaptureConsumer?.consumeFrame(frame)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        buffer.deallocate()
    }
    
    // MARK: - Private Helpers
    
    private func size(from preset: AVCaptureSession.Preset) -> CGSize {
        // Map common presets to CGSize
        switch preset {
        case .hd1280x720:  return CGSize(width: 1280, height: 720)
        case .hd1920x1080: return CGSize(width: 1920, height: 1080)
        case .vga640x480:  return CGSize(width: 640, height: 480)
        case .cif352x288:  return CGSize(width: 352, height: 288)
        default: return CGSize.zero
        }
    }
    
    private func currentDeviceOrientation() -> OTVideoOrientation {
        let orientation: UIInterfaceOrientation
        if #available(iOS 26.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                orientation = windowScene.effectiveGeometry.interfaceOrientation
            } else {
                orientation = .unknown
            }
        } else {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                orientation = windowScene.interfaceOrientation
            } else {
                orientation = .unknown
            }
        }
        
        let isFrontCamera = (self.inputDevice?.device.position == .front)
        
        if isFrontCamera {
            switch orientation {
            case .landscapeLeft:      return .up
            case .landscapeRight:     return .down
            case .portrait:           return .left
            case .portraitUpsideDown: return .right
            default:                  return .up
            }
        } else {
            switch orientation {
            case .landscapeLeft:      return .down
            case .landscapeRight:     return .up
            case .portrait:           return .left
            case .portraitUpsideDown: return .right
            default:                  return .up
            }
        }
    }
    
    private func bestFrameRate(for device: AVCaptureDevice) -> Double {
        var bestRate: Double = 0
        
        for range in device.activeFormat.videoSupportedFrameRateRanges {
            let duration = range.minFrameDuration
            // Calculate FPS: timescale / value
            let currentRate = Double(duration.timescale) / Double(duration.value)
            
            // Logic matches original: pick highest rate that is less than desired
            if currentRate > bestRate && currentRate < Double(desiredFrameRate) {
                bestRate = currentRate
            }
        }
        return bestRate
    }
}

