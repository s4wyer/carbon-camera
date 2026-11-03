// C01, C04, C07, C10, U02, U03, U13 — Camera Capture & AVFoundation Pipeline
// Baseline: Lapse SET §1, §2
// Overrides: D-002 (35mm default, auto flash, HEVC+RAW, zero sharpening)
// Persisted via CaptureJournal (SET04)

import AVFoundation
import Combine
import CoreMedia
import Photos
import os.log

/// Camera manager: AVFoundation session, capture, and device configuration.
/// Implements D-002 baseline (Lapse camera config) with overrides and durable journaling.
@MainActor
final class CameraManager: NSObject, ObservableObject {
    // MARK: - Published state
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var captureError: Error?
    @Published var lastCapturedShot: Shot?
    @Published var isCapacitorReady: Bool = true
    @Published var activeFocalLength: Double = 35.0
    @Published var activeFlashMode: AVCaptureDevice.FlashMode = .auto
    @Published var activeExposureEV: Float = 0.0
    @Published var activeWarmthK: Float = 0.0
    
    // MARK: - Private state
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "app.carbon.camera.session")
    private let logger = Logger(subsystem: "app.carbon", category: "CameraManager")
    
    private let preset: CaptureModePreset = .carbonDefault
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Session lifecycle
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureSession()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                Task { @MainActor in
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    // MARK: - Session configuration (Lapse SET §1 baseline + D-002)
    
    private func configureSession() {
        session.beginConfiguration()
        
        // Session preset: .photo / input priority (Lapse §1)
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        guard let device = selectBestDevice() else {
            logger.error("No suitable camera device found")
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoDeviceInput = input
                self.currentDevice = device
            }
        } catch {
            logger.error("Failed to create device input: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            // Lapse §1: Max quality prioritization
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            // Format setup (D-002: RAW+HEVC when available)
            if photoOutput.availableRawPhotoPixelFormatTypes.count > 0 {
                logger.info("Bayer RAW capture supported on device")
            }
        }
        
        session.commitConfiguration()
        
        // Device-level configurations
        configureDeviceSettings(device)
        
        // Start session on background queue
        session.startRunning()
        
        Task { @MainActor in
            self.isSessionRunning = self.session.isRunning
            self.activeFocalLength = self.preset.defaultFocalLengthEquivalentMM
            self.logger.info("Camera session started successfully")
        }
    }
    
    private func selectBestDevice() -> AVCaptureDevice? {
        // Prefer built-in triple / dual camera for 24/35/50 primes
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        return discoverySession.devices.first ?? AVCaptureDevice.default(for: .video)
    }
    
    private func configureDeviceSettings(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // Focus: Centered continuous AF (Lapse SET §1)
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = preset.defaultFocusPointOfInterest
                device.focusMode = .continuousAutoFocus
            }
            
            // Exposure: Centered continuous AE (Lapse SET §1)
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = preset.defaultExposurePointOfInterest
                device.exposureMode = .continuousAutoExposure
            }
            
            // Low-light boost & smooth autofocus (Lapse SET §1)
            if device.isLowLightBoostSupported && preset.enablesLowLightBoost {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            if device.isSmoothAutoFocusSupported && preset.enablesSmoothAutoFocus {
                device.isSmoothAutoFocusEnabled = true
            }
            
            // Initial zoom to 35mm equivalent (D-002)
            setZoomForFocalLength(preset.defaultFocalLengthEquivalentMM, on: device)
            
            device.unlockForConfiguration()
        } catch {
            logger.error("Failed to configure device: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Focal Length Selection (C10, D-025)
    
    func setFocalLength(_ focalLength: Double) {
        activeFocalLength = focalLength
        guard let device = currentDevice else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                self.setZoomForFocalLength(focalLength, on: device)
                device.unlockForConfiguration()
            } catch {
                self.logger.error("Failed to set focal length zoom: \(error.localizedDescription)")
            }
        }
    }
    
    private func setZoomForFocalLength(_ focalLength: Double, on device: AVCaptureDevice) {
        // Map 24/35/50mm to optical/digital zoom factor
        let factor: CGFloat
        switch focalLength {
        case 24: factor = 1.0  // Wide native
        case 35: factor = 1.45 // Natural portrait crop
        case 50: factor = 2.0  // 2x optical / crop
        default: factor = 1.45
        }
        
        let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        device.ramp(toVideoZoomFactor: clamped, withRate: 10.0) // ~200ms smooth transition
    }
    
    // MARK: - Flash Control (C07, U13, D-002)
    
    func cycleFlashMode() {
        switch activeFlashMode {
        case .auto: activeFlashMode = .on
        case .on: activeFlashMode = .off
        case .off: activeFlashMode = .auto
        @unknown default: activeFlashMode = .auto
        }
    }
    
    // MARK: - Exposure & Warmth (U02, U03, R08)
    
    func setExposureBias(_ ev: Float) {
        activeExposureEV = ev
        guard let device = currentDevice else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let clamped = min(max(ev, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                self.logger.error("Failed to set exposure bias: \(error.localizedDescription)")
            }
        }
    }
    
    func setWarmthK(_ kelvinOffset: Float) {
        activeWarmthK = kelvinOffset
    }
    
    // MARK: - Photo Capture (C01, C04, SET04)
    
    func capturePhoto() {
        guard isSessionRunning else {
            logger.warning("Capture requested while session not running")
            return
        }
        
        // Capacitor charging simulation (flash readiness)
        if activeFlashMode != .off {
            isCapacitorReady = false
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let settings = self.buildPhotoSettings()
            let captureID = UUID().uuidString
            
            let delegate = PhotoCaptureDelegate(captureID: captureID) { [weak self] result in
                guard let self = self else { return }
                Task { @MainActor in
                    self.isCapacitorReady = true
                    switch result {
                    case .success(let shot):
                        self.lastCapturedShot = shot
                        self.logger.info("Captured shot \(shot.captureID) committed to journal")
                    case .failure(let error):
                        self.captureError = error
                        self.logger.error("Capture failed: \(error.localizedDescription)")
                    }
                }
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
    
    private func buildPhotoSettings() -> AVCapturePhotoSettings {
        var settings: AVCapturePhotoSettings
        
        // Priority: RAW + HEVC pair (D-002)
        if photoOutput.availableRawPhotoPixelFormatTypes.count > 0,
           let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawFormat,
                processedFormat: [
                    AVVideoCodecKey: AVVideoCodecType.hevc,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoQualityKey: 0.95
                    ]
                ]
            )
        } else {
            // Fallback: HEVC only
            settings = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoCompressionPropertiesKey: [
                    AVVideoQualityKey: 0.95
                ]
            ])
        }
        
        // Flash
        if photoOutput.supportedFlashModes.contains(activeFlashMode) {
            settings.flashMode = activeFlashMode
        }
        
        settings.photoQualityPrioritization = .quality
        return settings
    }
}

// MARK: - Capture Delegate with Journal Persistence (SET04)

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let captureID: String
    private let completion: (Result<Shot, Error>) -> Void
    
    private var rawData: Data?
    private var hevcData: Data?
    private var captureMetadata: Shot.CaptureMetadata?
    
    init(captureID: String, completion: @escaping (Result<Shot, Error>) -> Void) {
        self.captureID = captureID
        self.completion = completion
    }
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = photo.fileDataRepresentation() else { return }
        
        if photo.isRawPhoto {
            rawData = data
        } else {
            hevcData = data
        }
        
        // Extract Lapse SET §2 metadata tuple
        let iso = photo.metadata[kCGImagePropertyExifISOSpeedRatings as String] as? Int ?? 100
        let expDuration = photo.metadata[kCGImagePropertyExifExposureTime as String] as? Double ?? (1.0 / 60.0)
        let cmDuration = CMTime(seconds: expDuration, preferredTimescale: 1000)
        
        captureMetadata = Shot.CaptureMetadata(
            temperature: 5500,
            tint: 0,
            iso: iso,
            exposureDuration: cmDuration,
            sceneEV: 8.0,
            flashState: .auto,
            lensPosition: 0.5,
            orientation: 1
        )
    }
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error = error {
            completion(.failure(error))
            return
        }
        
        Task {
            do {
                // Default recipe: Carbon Natural
                let defaultPreset = PresetLibrary.defaultPreset ?? PresetLibrary.all[0]
                let recipe = RecipeVersion(
                    recipeID: "natural-v1",
                    presetDefinitionID: defaultPreset.id,
                    engineVersion: "1.0",
                    source: rawData != nil ? .rawBayer : .processedHEVC,
                    parameters: RecipeVersion.Parameters(
                        filmPreset: defaultPreset.displayName,
                        filmStrength: 0.85,
                        exposureEV: 0.0,
                        temperatureK: 0.0,
                        tintOffset: 0.0,
                        contrastAmount: 1.0,
                        saturationAmount: 1.0
                    )
                )
                
                // Durable write to journal (SET04)
                let entry = try await CaptureJournal.shared.persist(
                    captureID: captureID,
                    rawBytes: rawData,
                    hevcBytes: hevcData,
                    recipe: recipe
                )
                
                // Build Shot model
                var sources: [SourceResource] = []
                if let rawName = entry.rawFilename, let rawHash = entry.rawSHA256 {
                    sources.append(SourceResource(
                        id: UUID(),
                        captureID: entry.captureID,
                        type: .rawBayer,
                        mediaURL: CaptureJournal.shared.fileURL(for: rawName),
                        mediaHash: rawHash,
                        provenance: SourceResource.Provenance(
                            engine: "carbon-camera",
                            version: "1.0.0",
                            timestamp: entry.timestamp,
                            isUserEditable: false
                        )
                    ))
                }
                if let hevcName = entry.hevcFilename, let hevcHash = entry.hevcSHA256 {
                    sources.append(SourceResource(
                        id: UUID(),
                        captureID: entry.captureID,
                        type: .processedHEVC,
                        mediaURL: CaptureJournal.shared.fileURL(for: hevcName),
                        mediaHash: hevcHash,
                        provenance: SourceResource.Provenance(
                            engine: "carbon-camera",
                            version: "1.0.0",
                            timestamp: entry.timestamp,
                            isUserEditable: true
                        )
                    ))
                }
                
                let shot = Shot(
                    id: entry.id,
                    captureID: captureID,
                    timestamp: entry.timestamp,
                    sources: sources,
                    currentRecipe: recipe,
                    captureMetadata: captureMetadata ?? Shot.CaptureMetadata(
                        temperature: 5500,
                        tint: 0,
                        iso: 100,
                        exposureDuration: CMTime(value: 1, timescale: 60),
                        sceneEV: 8.0,
                        flashState: .auto,
                        lensPosition: 0.5,
                        orientation: 1
                    )
                )
                
                completion(.success(shot))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
