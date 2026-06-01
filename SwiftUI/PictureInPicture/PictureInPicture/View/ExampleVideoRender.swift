import OpenTok
import GLKit
import Foundation
import UIKit


protocol ExampleVideoRenderDelegate {
    func renderer(_ renderer: ExampleVideoRender, didReceiveFrame videoFrame: OTVideoFrame)
}

class ExampleVideoRender: UIView {
    
    var delegate: ExampleVideoRenderDelegate?
    
    var frameLock = NSLock()
    var bufferDisplayLayer =  AVSampleBufferDisplayLayer()
    var pipBufferDisplayLayer: AVSampleBufferDisplayLayer?
    let accel = Accelerator()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension ExampleVideoRender: OTVideoRender {
    func renderVideoFrame(_ frame: OTVideoFrame) {
        if let format = frame.format {
            frameLock.lock()
            assert(format.pixelFormat == .I420)
            
            if let sampleBuffer = createSampleBufferWithVideoFrame(frame,
                                                                   width: Int(frame.format!.imageWidth),
                                                                   height: Int(frame.format!.imageHeight)) {
                bufferDisplayLayer.enqueue(sampleBuffer)
                pipBufferDisplayLayer?.enqueue(sampleBuffer)
            }
            
            frameLock.unlock()
        }
    }
    
    
    func createSampleBufferWithVideoFrame(_ frame: OTVideoFrame, width: Int, height: Int) -> CMSampleBuffer? {
        
        let pixelAttributes: NSDictionary = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, pixelAttributes as CFDictionary, &pixelBuffer)
        
        guard result == 0 else {
            return nil
        }
        _ = accel.convertFrameVImageYUV(frame, to: pixelBuffer)
        let s = createSampleBufferFrom(pixelBuffer: pixelBuffer!)
        
        
        return s
    }
    
    func createSampleBufferFrom(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        var sampleBuffer: CMSampleBuffer?
        
        
        let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), preferredTimescale: 1000)
        var timingInfo = CMSampleTimingInfo(duration: CMTimeMakeWithSeconds(1, preferredTimescale: 1000), presentationTimeStamp: now, decodeTimeStamp: now)
        var formatDescription: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        
        let osStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if osStatus != noErr {
            let errorMessage = osStatusToString(status: osStatus)
            print("osStatus error: \(errorMessage)")
        }
        
        guard let buffer = sampleBuffer else {
            print("Cannot create sample buffer")
            return nil
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        return buffer
    }
    
    func osStatusToString(status: OSStatus) -> String {
        switch status {
        case kCMSampleBufferError_DataCanceled:
            return "kCMSampleBufferError_DataCanceled"
        case kCMSampleBufferError_DataFailed:
            return "kCMSampleBufferError_DataFailed"
        case kCMSampleBufferError_Invalidated:
            return "kCMSampleBufferError_Invalidated"
        case kCMSampleBufferError_InvalidMediaFormat:
            return "kCMSampleBufferError_InvalidMediaFormat"
        case kCMSampleBufferError_InvalidSampleData:
            return "kCMSampleBufferError_InvalidSampleData"
        case kCMSampleBufferError_InvalidMediaTypeForOperation:
            return "kCMSampleBufferError_InvalidMediaTypeForOperation"
        case kCMSampleBufferError_SampleTimingInfoInvalid:
            return "kCMSampleBufferError_SampleTimingInfoInvalid"
        case kCMSampleBufferError_CannotSubdivide:
            return "kCMSampleBufferError_CannotSubdivide"
        case kCMSampleBufferError_InvalidEntryCount:
            return "kCMSampleBufferError_InvalidEntryCount"
        case kCMSampleBufferError_ArrayTooSmall:
            return "kCMSampleBufferError_ArrayTooSmall"
        case kCMSampleBufferError_BufferHasNoSampleTimingInfo:
            return "kCMSampleBufferError_BufferHasNoSampleTimingInfo"
        case kCMSampleBufferError_BufferHasNoSampleSizes:
            return "kCMSampleBufferError_BufferHasNoSampleSizes"
        case kCMSampleBufferError_SampleIndexOutOfRange:
            return "kCMSampleBufferError_SampleIndexOutOfRange"
        case kCMSampleBufferError_BufferNotReady:
            return "kCMSampleBufferError_BufferNotReady"
        case kCMSampleBufferError_AlreadyHasDataBuffer:
            return "kCMSampleBufferError_AlreadyHasDataBuffer"
        case kCMSampleBufferError_RequiredParameterMissing:
            return "kCMSampleBufferError_RequiredParameterMissing"
        case kCMSampleBufferError_AllocationFailed:
            return "kCMSampleBufferError_AllocationFailed"
        default:
            return "Unknown error with code \(status)"
        }
    }
    
  }

