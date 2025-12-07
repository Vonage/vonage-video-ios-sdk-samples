//
//  OTDefaultAudioDevice.swift
//
//  Swift port of OTDefaultAudioDevice.mm
//  Implements low-level AudioUnit playout + capture
//

import Foundation
import AVFoundation
import AudioToolbox
import OpenTok

final class Atomic<T> {
    private let lock = DispatchSemaphore(value: 1)
    private var valueStorage: T
    init(_ v: T) { valueStorage = v }
    var value: T {
        get { lock.wait(); defer { lock.signal() }; return valueStorage }
        set { lock.wait(); valueStorage = newValue; lock.signal() }
    }
}

public final class OTDefaultAudioDevice: NSObject, OTAudioDevice {
    private var audioFormat: OTAudioFormat
    private var recordingUnit: AudioUnit?
    private var playoutUnit: AudioUnit?

    private let safetyQueue = DispatchQueue(label: "OTAudioDeviceSafetyQueue")

    private var playing     = Atomic(false)
    private var recording   = Atomic(false)

    private var playoutInitialized  = false
    private var recordingInitialized = false

    private var isAudioSessionSetup = false
    private var isResetting = false

    private var isPlayerInterrupted = false
    private var isRecorderInterrupted = false

    private var restartRetryCount = 0
    private let RETRY_COUNT = 5

    private var sampleRate: Int
    private var componentSubType: OSType = kAudioUnitSubType_VoiceProcessingIO

    private var previousCategory: AVAudioSession.Category = .soloAmbient
    private var previousMode: AVAudioSession.Mode = .default
    private var previousPrefSampleRate: Double = 0
    private var previousPrefChannels: Int = 1

    // Buffer
    private var bufferList: UnsafeMutablePointer<AudioBufferList>?
    private var bufferNumFrames: UInt32 = 0
    private var bufferSize: UInt32 = 0

    // Delay estimation
    private var recordingDelay = Atomic(UInt32(0))
    private var playoutDelay = Atomic(UInt32(0))
    private var recDelayCounter: UInt32 = 0
    private var playDelayCounter: UInt32 = 0
    private var recLatencyAU: Float64 = 0
    private var playLatencyAU: Float64 = 0

    // Route detection
    public private(set) var headsetDeviceAvailable = false
    public private(set) var bluetoothDeviceAvailable = false

    private var listenerSetup = false
    private weak var audioBus: OTAudioBus?

    // Constants
    private let preferredIOBufferDuration = 0.01
    private let maxPlayoutDelay: UInt32 = 150
    private let maxRecordingDelay: UInt32 = 500
    private let latencyCompensationUS: UInt32 = 500  // same as kLatencyDelay (µs)

    // -------------------------------------------------------------------------
    // MARK: - Init
    // -------------------------------------------------------------------------

    public override init() {
        let session = AVAudioSession.sharedInstance()
        sampleRate = Int(session.sampleRate)

        // On mac "Designed for iPad" mode use RemoteIO
        if UIDevice.current.userInterfaceIdiom == .pad,
           NSClassFromString("NSApplication") != nil {
            componentSubType = kAudioUnitSubType_RemoteIO
        } else {
            componentSubType = kAudioUnitSubType_VoiceProcessingIO
        }

        audioFormat = OTAudioFormat()
        audioFormat.numChannels = 1
        audioFormat.sampleRate = UInt16(sampleRate)

        super.init()
    }

    deinit {
        removeObservers()
        teardownAudio()
    }

    // -------------------------------------------------------------------------
    // MARK: - OTAudioDevice methods
    // -------------------------------------------------------------------------

    public func setAudioBus(_ audioBus: OTAudioBus?) -> Bool {
        self.audioBus = audioBus
        audioFormat = OTAudioFormat()
        audioFormat.numChannels = 1
        audioFormat.sampleRate = UInt16(sampleRate)
        return true
    }

    public func captureFormat() -> OTAudioFormat {
        audioFormat
    }

    public func renderFormat() -> OTAudioFormat {
        audioFormat
    }

    public func renderingIsAvailable() -> Bool { true }
    public func captureIsAvailable() -> Bool { true }

    public func renderingIsInitialized() -> Bool {
        playoutInitialized
    }

    public func captureIsInitialized() -> Bool {
        recordingInitialized
    }

    public func initializeRendering() -> Bool {
        if playing.value { return false }
        if playoutInitialized { return true }
        playoutInitialized = true
        return true
    }

    public func initializeCapture() -> Bool {
        if recording.value { return false }
        if recordingInitialized { return true }
        recordingInitialized = true
        return true
    }

    // -------------------------------------------------------------------------
    // MARK: Rendering Start/Stop
    // -------------------------------------------------------------------------

    public func startRendering() -> Bool {
        objc_sync_enter(self); defer { objc_sync_exit(self) }

        if playing.value { return true }
        playing.value = true

        if playoutUnit == nil {
            guard setupAudioUnit(&playoutUnit, isPlayout: true) else {
                playing.value = false
                return false
            }
        }

        let status = AudioOutputUnitStart(playoutUnit!)
        if status != noErr {
            playing.value = false
            return false
        }
        return true
    }

    public func stopRendering() -> Bool {
        objc_sync_enter(self); defer { objc_sync_exit(self) }

        if playing.value == false { return true }
        playing.value = false

        if let unit = playoutUnit {
            AudioOutputUnitStop(unit)
        }

        if !recording.value && !isPlayerInterrupted && !isResetting {
            teardownAudio()
        }
        return true
    }

    public func isRendering() -> Bool {
        playing.value
    }

    // -------------------------------------------------------------------------
    // MARK: Capture Start/Stop
    // -------------------------------------------------------------------------

    public func startCapture() -> Bool {
        objc_sync_enter(self); defer { objc_sync_exit(self) }

        if recording.value { return true }
        recording.value = true

        if recordingUnit == nil {
            guard setupAudioUnit(&recordingUnit, isPlayout: false) else {
                recording.value = false
                return false
            }
        }

        let status = AudioOutputUnitStart(recordingUnit!)
        if status != noErr {
            recording.value = false
            return false
        }
        return true
    }

    public func stopCapture() -> Bool {
        objc_sync_enter(self); defer { objc_sync_exit(self) }

        if recording.value == false { return true }
        recording.value = false

        if let unit = recordingUnit {
            AudioOutputUnitStop(unit)
        }

        freeBuffer()

        if !playing.value && !isRecorderInterrupted && !isResetting {
            teardownAudio()
        }
        return true
    }

    public func isCapturing() -> Bool {
        recording.value
    }

    // -------------------------------------------------------------------------
    // MARK: Estimated Delays
    // -------------------------------------------------------------------------

    public func estimatedRenderDelay() -> UInt16 {
        min(UInt16(playoutDelay.value), 150)
    }

    public func estimatedCaptureDelay() -> UInt16 {
        min(UInt16(recordingDelay.value), 500)
    }

    // -------------------------------------------------------------------------
    // MARK: - Audio Session Setup / Teardown
    // -------------------------------------------------------------------------

    private func setupAudioSession() {
        if isAudioSessionSetup { return }

        let session = AVAudioSession.sharedInstance()

        // Save previous
        previousCategory = session.category
        previousMode = session.mode
        previousPrefSampleRate = session.preferredSampleRate
        previousPrefChannels = session.inputNumberOfChannels

        // Configure
        try? session.setPreferredSampleRate(Double(sampleRate))
        try? session.setPreferredInputNumberOfChannels(1)
        try? session.setPreferredIOBufferDuration(preferredIOBufferDuration)

        #if !os(tvOS)
        try? session.setCategory(.playAndRecord,
                                 mode: .videoChat,
                                 options: [
                                    .allowBluetooth,
                                    .defaultToSpeaker
                                 ])
        #else
        try? session.setCategory(.playback)
        #endif

        setupListeners()
        try? session.setActive(true)

        setBluetoothAsPreferredInputDevice()

        isAudioSessionSetup = true
    }

    private func teardownAudio() {
        disposePlayoutUnit()
        disposeRecordUnit()
        freeBuffer()

        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(previousCategory)
        try? s.setMode(previousMode)
        try? s.setPreferredSampleRate(previousPrefSampleRate)
        try? s.setPreferredInputNumberOfChannels(previousPrefChannels)
        try? s.setActive(false, options: .notifyOthersOnDeactivation)

        isAudioSessionSetup = false
    }

    // -------------------------------------------------------------------------
    // MARK: - Unit Disposal
    // -------------------------------------------------------------------------

    private func disposePlayoutUnit() {
        if let u = playoutUnit {
            AudioUnitUninitialize(u)
            AudioComponentInstanceDispose(u)
        }
        playoutUnit = nil
    }

    private func disposeRecordUnit() {
        if let u = recordingUnit {
            AudioUnitUninitialize(u)
            AudioComponentInstanceDispose(u)
        }
        recordingUnit = nil
    }

    private func freeBuffer() {
        if let bufferList = bufferList {
            let ptr = bufferList.pointee.mBuffers.mData
            ptr?.deallocate()
            bufferList.deallocate()
        }
        bufferList = nil
        bufferNumFrames = 0
    }

    // -------------------------------------------------------------------------
    // MARK: - Setup AudioUnit (low-level)
// -------------------------------------------------------------------------

    private func setupAudioUnit(_ unit: inout AudioUnit?, isPlayout: Bool) -> Bool {

        setupAudioSession()

        //------------------------------------------------
        // AudioStreamBasicDescription
        //------------------------------------------------
        var asbd = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        //------------------------------------------------
        // Component description
        //------------------------------------------------
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: componentSubType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let comp = AudioComponentFindNext(nil, &desc) else { return false }
        var au: AudioUnit?
        guard AudioComponentInstanceNew(comp, &au) == noErr else { return false }

        //------------------------------------------------
        // Configure input/output buses
        //------------------------------------------------

        if isPlayout == false {
            // ENABLE INPUT
            var enable: UInt32 = 1
            AudioUnitSetProperty(au!,
                                 kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Input,
                                 1, // input bus
                                 &enable,
                                 4)

            // FORMAT
            AudioUnitSetProperty(au!,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output,
                                 1,
                                 &asbd,
                                 UInt32(MemoryLayout.size(ofValue: asbd)))

            // CALLBACK
            var cb = AURenderCallbackStruct(
                inputProc: recordingCallback,
                inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
            )

            AudioUnitSetProperty(au!,
                                 kAudioOutputUnitProperty_SetInputCallback,
                                 kAudioUnitScope_Global,
                                 1,
                                 &cb,
                                 UInt32(MemoryLayout.size(ofValue: cb)))

            // DISABLE OUTPUT ON RECORD UNIT
            var disable: UInt32 = 0
            AudioUnitSetProperty(au!,
                                 kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Output,
                                 0,
                                 &disable,
                                 4)

        } else {
            //------------------------------------------------
            // Playout unit CONFIG
            //------------------------------------------------
            var enable: UInt32 = 1
            AudioUnitSetProperty(au!,
                                 kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Output,
                                 0,
                                 &enable,
                                 4)

            AudioUnitSetProperty(au!,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input,
                                 0,
                                 &asbd,
                                 UInt32(MemoryLayout.size(ofValue: asbd)))

            var disableInput: UInt32 = 0
            AudioUnitSetProperty(au!,
                                 kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Input,
                                 1,
                                 &disableInput,
                                 4)

            // PLAYOUT CALLBACK
            var cb = AURenderCallbackStruct(
                inputProc: playoutCallback,
                inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
            )

            AudioUnitSetProperty(au!,
                                 kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input,
                                 0,
                                 &cb,
                                 UInt32(MemoryLayout.size(ofValue: cb)))
        }

        //------------------------------------------------
        // Get latency from AU
        //------------------------------------------------
        var latency: Float64 = 0
        var size = UInt32(MemoryLayout.size(ofValue: latency))
        if AudioUnitGetProperty(au!,
                                kAudioUnitProperty_Latency,
                                kAudioUnitScope_Global,
                                0,
                                &latency,
                                &size) == noErr
        {
            if isPlayout { playLatencyAU = latency }
            else { recLatencyAU = latency }
        }

        //------------------------------------------------
        // Initialize the AU (retry logic from .mm)
        //------------------------------------------------
        var result = AudioUnitInitialize(au!)
        var attempts = 0
        while result != noErr && attempts < 5 {
            Thread.sleep(forTimeInterval: 0.1)
            result = AudioUnitInitialize(au!)
            attempts += 1
        }
        guard result == noErr else { return false }

        unit = au
        return true
    }


    // -------------------------------------------------------------------------
    // MARK: - Callbacks
    // -------------------------------------------------------------------------

    private let recordingCallback: AURenderCallback = { ref, flags, ts, bus, frames, data in
        let dev = Unmanaged<OTDefaultAudioDevice>.fromOpaque(ref).takeUnretainedValue()
        return dev.handleRecordingCallback(flags: flags, ts: ts, frames: frames)
    }

    private let playoutCallback: AURenderCallback = { ref, flags, ts, bus, frames, bufferList in
        let dev = Unmanaged<OTDefaultAudioDevice>.fromOpaque(ref).takeUnretainedValue()
        return dev.handlePlayoutCallback(flags: flags, ts: ts, frames: frames, bufferList)
    }


    private func handleRecordingCallback(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>?,
                                         ts: UnsafePointer<AudioTimeStamp>?,
                                         frames: UInt32) -> OSStatus {

        // Allocate buffer if needed
        if bufferList == nil || frames > bufferNumFrames {
            if let b = bufferList {
                b.pointee.mBuffers.mData?.deallocate()
                b.deallocate()
            }

            let abl = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            abl.pointee.mNumberBuffers = 1
            abl.pointee.mBuffers.mNumberChannels = 1

            let bytes = Int(frames) * MemoryLayout<Int16>.size
            let data = UnsafeMutableRawPointer.allocate(byteCount: bytes,
                                                        alignment: MemoryLayout<Int16>.alignment)
            abl.pointee.mBuffers.mData = data
            abl.pointee.mBuffers.mDataByteSize = UInt32(bytes)

            bufferList = abl
            bufferNumFrames = frames
            bufferSize = UInt32(bytes)
        }

        guard let unit = recordingUnit else { return noErr }
        let status = AudioUnitRender(unit,
                                     flags,
                                     ts,
                                     1,
                                     frames,
                                     bufferList!)
        if status != noErr { return status }

        if recording.value {
            if let data = bufferList?.pointee.mBuffers.mData {
                audioBus?.writeCaptureData(data,
                                           numberOfSamples: frames)
            }
        }

        updateRecordingDelay()
        return noErr
    }


    private func handlePlayoutCallback(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>?,
                                       ts: UnsafePointer<AudioTimeStamp>?,
                                       frames: UInt32,
                                       _ bufferList: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {

        if !playing.value { return noErr }

        if let bus = audioBus,
           let buffer = bufferList?.pointee.mBuffers.mData {

            let count = bus.readRenderData(buffer, numberOfSamples: frames)
            _ = count
        }

        updatePlayoutDelay()
        return noErr
    }

    // -------------------------------------------------------------------------
    // MARK: - Delay Updates (match .mm logic)
    // -------------------------------------------------------------------------

    private func updateRecordingDelay() {
        recDelayCounter += 1
        if recDelayCounter < 100 { return }
        recDelayCounter = 0

        let session = AVAudioSession.sharedInstance()
        var delayUS: UInt32 = 0

        delayUS += UInt32(session.inputLatency * 1_000_000)
        delayUS += UInt32(session.ioBufferDuration * 1_000_000)
        delayUS += UInt32(recLatencyAU * 1_000_000)

        if delayUS > latencyCompensationUS {
            delayUS = (delayUS - latencyCompensationUS) / 1000
        } else {
            delayUS = delayUS / 1000
        }

        recordingDelay.value = delayUS
    }

    private func updatePlayoutDelay() {
        playDelayCounter += 1
        if playDelayCounter < 100 { return }
        playDelayCounter = 0

        let session = AVAudioSession.sharedInstance()
        var delayUS: UInt32 = 0

        delayUS += UInt32(session.outputLatency * 1_000_000)
        delayUS += UInt32(session.ioBufferDuration * 1_000_000)
        delayUS += UInt32(playLatencyAU * 1_000_000)

        if delayUS > latencyCompensationUS {
            delayUS = (delayUS - latencyCompensationUS) / 1000
        } else {
            delayUS = delayUS / 1000
        }

        playoutDelay.value = delayUS
    }

    // -------------------------------------------------------------------------
    // MARK: - Route Changes / Interruptions
    // -------------------------------------------------------------------------

    private func setupListeners() {
        if listenerSetup { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        listenerSetup = true
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        listenerSetup = false
    }

    // -------------------------------------------------------
    // Interruption
    // -------------------------------------------------------

    @objc private func onInterruption(_ n: Notification) {
        guard let typeVal =
            n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }

        let type = AVAudioSession.InterruptionType(rawValue: typeVal) ?? .began

        safetyQueue.async {
            self.handleInterruption(type)
        }
    }

    private func handleInterruption(_ type: AVAudioSession.InterruptionType) {
        objc_sync_enter(self); defer { objc_sync_exit(self) }

        switch type {
        case .began:
            if recording.value {
                isRecorderInterrupted = true
                stopCapture()
            }
            if playing.value {
                isPlayerInterrupted = true
                stopRendering()
            }

        case .ended:
            setBluetoothAsPreferredInputDevice()

            if isRecorderInterrupted { restartCaptureAfterInterrupt() }
            if isPlayerInterrupted { restartPlayoutAfterInterrupt() }

        @unknown default: break
        }
    }

    private func restartCaptureAfterInterrupt() {
        if startCapture() {
            isRecorderInterrupted = false
            restartRetryCount = 0
            return
        }

        retryRestart {
            self.restartCaptureAfterInterrupt()
        }
    }

    private func restartPlayoutAfterInterrupt() {
        if startRendering() {
            isPlayerInterrupted = false
            restartRetryCount = 0
            return
        }

        retryRestart {
            self.restartPlayoutAfterInterrupt()
        }
    }

    private func retryRestart(_ f: @escaping () -> Void) {
        restartRetryCount += 1
        if restartRetryCount < RETRY_COUNT {
            safetyQueue.asyncAfter(deadline: .now() + 1.0) { f() }
        } else {
            restartRetryCount = 0
            isRecorderInterrupted = false
            isPlayerInterrupted = false
        }
    }

    // -------------------------------------------------------
    // Media Services Reset
    // -------------------------------------------------------

    @objc private func onMediaServicesReset(_ n: Notification) {
        safetyQueue.async { self.restartAudioUnits() }
    }

    // -------------------------------------------------------
    // App Active (no END interruption callback sometimes)
    // -------------------------------------------------------

    @objc private func appDidBecomeActive(_ n: Notification) {
        safetyQueue.async {
            self.handleInterruption(.ended)
        }
    }

    // -------------------------------------------------------
    // Route Changes
    // -------------------------------------------------------

    @objc private func onRouteChange(_ n: Notification) {
        safetyQueue.async {
            self.handleRouteChange(n)
        }
    }

    private func handleRouteChange(_ n: Notification) {
        guard let reasonVal =
            n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }

        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal) else { return }

        switch reason {
        case .categoryChange,
             .routeConfigurationChange:
            return

        default: break
        }

        restartAudioUnits()
    }

    // -------------------------------------------------------
    // Restart units on route change
    // -------------------------------------------------------

    private func restartAudioUnits() {
        objc_sync_enter(self); defer { objc_sync_exit(self) }
        isResetting = true

        if recording.value {
            stopCapture()
            disposeRecordUnit()
            _ = startCapture()
        }

        if playing.value {
            stopRendering()
            disposePlayoutUnit()
            _ = startRendering()
        }

        isResetting = false
    }


    // -------------------------------------------------------------------------
    // MARK: - Bluetooth / Speaker Selection
    // -------------------------------------------------------------------------

    public func setBuiltInSpeakerAsPreferredOutput() {
        try? AVAudioSession.sharedInstance()
            .overrideOutputAudioPort(.speaker)
    }

    public func setBluetoothAsPreferredInputDevice() {
        let session = AVAudioSession.sharedInstance()

        for input in session.availableInputs ?? [] {
            switch input.portType {
            case .bluetoothHFP, .bluetoothLE, .bluetoothA2DP:
                try? session.setPreferredInput(input)
                return
            default: continue
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: - Route Detection
    // -------------------------------------------------------------------------

    @discardableResult
    public func detectCurrentRoute() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute

        headsetDeviceAvailable = false
        bluetoothDeviceAvailable = false

        for o in route.outputs {
            switch o.portType {
            case .headphones, .headsetMic:
                headsetDeviceAvailable = true
            case .bluetoothHFP, .bluetoothLE, .bluetoothA2DP:
                bluetoothDeviceAvailable = true
            default: break
            }
        }

        return true
    }

    // -------------------------------------------------------------------------
    // MARK: - Desired Route Selection (Bluetooth → Headset → Speaker)
// -------------------------------------------------------------------------

    @discardableResult
    public func configureAudioSessionWithDesiredAudioRoute(_ desired: String?) -> Bool {

        detectCurrentRoute()

        if bluetoothDeviceAvailable {
            setBluetoothAsPreferredInputDevice()
            return true
        }

        if headsetDeviceAvailable {
            return true
        }

        setBuiltInSpeakerAsPreferredOutput()
        return true
    }

    // Required by protocol but unused
    public func setPlayOutRenderCallback(_ unit: AudioUnit) -> Bool {
        return true
    }
}
