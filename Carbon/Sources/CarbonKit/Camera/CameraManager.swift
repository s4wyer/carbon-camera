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
    @Published var activeAspectRatio: PhotoAspectRatio =
        PhotoAspectRatio(rawValue: UserDefaults.standard.string(forKey: "camera.aspectRatio") ?? "") ?? .twoByThree {
        didSet { UserDefaults.standard.set(activeAspectRatio.rawValue, forKey: "camera.aspectRatio") }
    }
    @Published var activeExposureEV: Float = 0.0
    @Published var activeWarmthK: Float = 0.0
    @Published var activePreset: PresetDefinition = PresetLibrary.defaultPreset ?? PresetLibrary.all[0]
    @Published var currentSceneEV: Float = 8.0  // C03A: updated from live ISO/shutter readings
    
    // MARK: - Private state
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var sessionConfigured = false
    private var pendingExposureWorkItem: DispatchWorkItem?
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
            if self.sessionConfigured {
                self.session.startRunning()
                Task { @MainActor in
                    self.isSessionRunning = self.session.isRunning
                }
            } else {
                self.configureSession()
            }
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
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            self.videoDeviceInput = input
            self.currentDevice = device
        } catch {
            logger.error("Failed to create device input: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(photoOutput)
        photoOutput.isLivePhotoCaptureEnabled = false
        photoOutput.isDepthDataDeliveryEnabled = false
        
        // Lapse §1: output allows quality; per-shot priority adapts to scene EV.
        photoOutput.maxPhotoQualityPrioritization = .quality
        if let dimensions = Self.photoDimensions4x3(photoOutput.supportedPhotoDimensions).last {
            photoOutput.maxPhotoDimensions = dimensions
        }

        // Format setup (D-002: RAW+HEVC when available)
        if photoOutput.availableRawPhotoPixelFormatTypes.count > 0 {
            logger.info("Bayer RAW capture supported on device")
        }

        session.commitConfiguration()
        sessionConfigured = true
        
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
            
            // Lapse §1 requests 30 fps where the active format supports it.
            let supports30FPS = device.activeFormat.videoSupportedFrameRateRanges.contains {
                $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
            }
            if supports30FPS {
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
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
        
        let clamped = Self.clampedZoomFactor(
            factor,
            minimum: device.minAvailableVideoZoomFactor,
            maximum: device.maxAvailableVideoZoomFactor
        )
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
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        activeFlashMode = mode
    }
    
    /// Set the preset used for the next capture's recipe and render queue.
    func setActivePreset(_ preset: PresetDefinition) {
        activePreset = preset
    }
    
    // MARK: - Exposure & Warmth (U02, U03, R08)
    
    func setExposureBias(_ ev: Float) {
        activeExposureEV = ev
        pendingExposureWorkItem?.cancel()
        guard let device = currentDevice else { return }

        let workItem = DispatchWorkItem { [weak self, device] in
            do {
                try device.lockForConfiguration()
                let clamped = min(max(ev, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                self?.logger.error("Failed to set exposure bias: \(error.localizedDescription)")
            }
        }
        pendingExposureWorkItem = workItem
        sessionQueue.asyncAfter(deadline: .now() + 0.016, execute: workItem)
    }
    
    func setWarmthK(_ kelvinOffset: Float) {
        activeWarmthK = kelvinOffset
    }
    
    func setFocusAndExposure(at point: CGPoint) {
        guard let device = currentDevice else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }

                device.unlockForConfiguration()
            } catch {
                self.logger.error("Failed to set focus/exposure point: \(error.localizedDescription)")
            }
        }
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
        
        let aspectRatio = activeAspectRatio
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let settings = self.buildPhotoSettings()
            let captureID = UUID().uuidString
            
            let delegate = PhotoCaptureDelegate(
                captureID: captureID,
                flashMode: self.activeFlashMode,
                preset: self.activePreset,
                aspectRatio: aspectRatio,
                device: self.currentDevice
            ) { [weak self] result in
                guard let self = self else { return }
                Task { @MainActor in
                    self.isCapacitorReady = true
                    switch result {
                    case .success(let shot):
                        self.lastCapturedShot = shot
                        self.currentSceneEV = shot.captureMetadata?.sceneEV ?? 8.0
                        RollStore.shared.addShot(shot.id)
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
        if let device = currentDevice, device.exposureDuration.seconds > 0, device.iso > 0 {
            currentSceneEV = Self.sceneEV(
                aperture: Float(device.lensAperture),
                iso: device.iso,
                exposureSeconds: device.exposureDuration.seconds
            )
        }
        var settings = Self.makePhotoSettings(
            rawPixelFormatType: Self.isLapsePreset(activePreset) ? nil : photoOutput.availableRawPhotoPixelFormatTypes.first,
            maximumQuality: photoOutput.maxPhotoQualityPrioritization,
            flashMode: activeFlashMode,
            supportedFlashModes: photoOutput.supportedFlashModes,
            sceneEV: currentSceneEV
        )
        if let dimensions = Self.photoDimensions4x3(photoOutput.supportedPhotoDimensions).last {
            settings.maxPhotoDimensions = dimensions
        }
        return settings
    }

    // Keep settings construction independent of camera hardware so the RAW and
    // processed-only paths can both be exercised by simulator regression tests.
    nonisolated static func makePhotoSettings(
        rawPixelFormatType: OSType?,
        maximumQuality: AVCapturePhotoOutput.QualityPrioritization,
        flashMode: AVCaptureDevice.FlashMode,
        supportedFlashModes: [AVCaptureDevice.FlashMode],
        sceneEV: Float = 0
    ) -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings

        // Priority: RAW + HEVC pair (D-002)
        if let rawFormat = rawPixelFormatType {
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
        
        settings.isDepthDataDeliveryEnabled = false
        settings.isPortraitEffectsMatteDeliveryEnabled = false
        settings.enabledSemanticSegmentationMatteTypes = []

        // Flash
        if supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        
        // Bayer RAW requires .speed; processed-only captures use Lapse's EV rule.
        settings.photoQualityPrioritization = Self.qualityPrioritization(
            isBayerRAW: AVCapturePhotoOutput.isBayerRAWPixelFormat(settings.rawPhotoPixelFormatType),
            sceneEV: sceneEV,
            maximumQuality: maximumQuality
        )
        return settings
    }

    nonisolated static func isLapsePreset(_ preset: PresetDefinition) -> Bool {
        if case .lapseReference = preset.source { return true }
        return false
    }

    nonisolated static func sceneEV(aperture: Float, iso: Float, exposureSeconds: Double) -> Float {
        guard aperture.isFinite, aperture > 0, iso.isFinite, iso > 0,
              exposureSeconds.isFinite, exposureSeconds > 0 else { return 8.0 }
        return log2(aperture * aperture / ((iso / 100.0) * Float(exposureSeconds)))
    }

    nonisolated static func qualityPrioritization(
        isBayerRAW: Bool,
        sceneEV: Float,
        maximumQuality: AVCapturePhotoOutput.QualityPrioritization
    ) -> AVCapturePhotoOutput.QualityPrioritization {
        if isBayerRAW { return .speed }
        return sceneEV > 6.0 ? .balanced : maximumQuality
    }

    nonisolated static func photoDimensions4x3(_ dimensions: [CMVideoDimensions]) -> [CMVideoDimensions] {
        dimensions.filter { dimension in
            guard dimension.width > 0, dimension.height > 0 else { return false }
            return abs(Float(dimension.width) / Float(dimension.height) - (4.0 / 3.0)) < 0.01
        }
    }

    nonisolated static func clampedZoomFactor(_ requested: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        max(minimum, min(requested, min(maximum, 20.0)))
    }

    nonisolated static func whiteBalanceMetadata(
        redGain: Float?, greenGain: Float?, blueGain: Float?, maximumGain: Float,
        convertedTemperature: Float?, convertedTint: Float?
    ) -> (temperature: Float, tint: Float) {
        guard let redGain, let greenGain, let blueGain,
              redGain.isFinite, greenGain.isFinite, blueGain.isFinite,
              redGain >= 1, greenGain >= 1, blueGain >= 1,
              redGain < maximumGain, greenGain < maximumGain, blueGain < maximumGain,
              let temperature = convertedTemperature, temperature.isFinite,
              let tint = convertedTint, tint.isFinite else { return (4000, 0) }
        return (temperature, tint)
    }
    
    /// C02: Safety capture — request 3 frames when enabled (D-025: off by default)
    func captureWithSafety() {
        guard isSessionRunning else { return }
        
        let aspectRatio = activeAspectRatio
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // C02: Fire 3 rapid captures, group as one logical shot
            for i in 0..<3 {
                let settings = self.buildPhotoSettings()
                let captureID = "safety-\(UUID().uuidString)-frame\(i)"
                
                let delegate = PhotoCaptureDelegate(
                    captureID: captureID,
                    flashMode: self.activeFlashMode,
                    preset: self.activePreset,
                    aspectRatio: aspectRatio,
                    device: self.currentDevice
                ) { [weak self] result in
                    guard let self = self else { return }
                    Task { @MainActor in
                        switch result {
                        case .success(let shot):
                            self.lastCapturedShot = shot
                            RollStore.shared.addShot(shot.id)
                        case .failure(let error):
                            self.captureError = error
                        }
                    }
                }
                
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }
}

// MARK: - Capture Delegate with Journal Persistence (SET04)

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let captureID: String
    private let requestedFlashMode: AVCaptureDevice.FlashMode
    private let capturePreset: PresetDefinition
    private let aspectRatio: PhotoAspectRatio
    private let device: AVCaptureDevice?
    private let completion: (Result<Shot, Error>) -> Void
    
    private var rawData: Data?
    private var hevcData: Data?
    private var captureMetadata: Shot.CaptureMetadata?
    
    init(
        captureID: String,
        flashMode: AVCaptureDevice.FlashMode,
        preset: PresetDefinition,
        aspectRatio: PhotoAspectRatio,
        device: AVCaptureDevice?,
        completion: @escaping (Result<Shot, Error>) -> Void
    ) {
        self.captureID = captureID
        self.requestedFlashMode = flashMode
        self.capturePreset = preset
        self.aspectRatio = aspectRatio
        self.device = device
        self.completion = completion
    }
    
    private func captureWhiteBalanceMetadata() -> (temperature: Float, tint: Float) {
        guard let device else { return (4000, 0) }
        let gains = device.deviceWhiteBalanceGains
        guard gains.redGain >= 1, gains.greenGain >= 1, gains.blueGain >= 1,
              gains.redGain < device.maxWhiteBalanceGain,
              gains.greenGain < device.maxWhiteBalanceGain,
              gains.blueGain < device.maxWhiteBalanceGain else { return (4000, 0) }
        let converted = device.temperatureAndTintValues(for: gains)
        return CameraManager.whiteBalanceMetadata(
            redGain: gains.redGain,
            greenGain: gains.greenGain,
            blueGain: gains.blueGain,
            maximumGain: device.maxWhiteBalanceGain,
            convertedTemperature: converted.temperature,
            convertedTint: converted.tint
        )
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
        let metadata = photo.metadata
        let iso = (metadata[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first ?? 0
        let expDuration = metadata[kCGImagePropertyExifExposureTime as String] as? Double ?? 0
        let cmDuration = CMTime(seconds: expDuration, preferredTimescale: 1000)
        
        let orientation = metadata[kCGImagePropertyOrientation as String] as? Int ?? 1
        let wb = captureWhiteBalanceMetadata()
        let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let aperture = exif?[kCGImagePropertyExifFNumber as String] as? Float ?? 1.8
        let sceneEV = CameraManager.sceneEV(aperture: aperture, iso: Float(iso), exposureSeconds: expDuration)
        
        captureMetadata = Shot.CaptureMetadata(
            temperature: wb.temperature,
            tint: wb.tint,
            iso: Float(iso > 0 ? iso : 100),
            exposureDuration: cmDuration,
            sceneEV: sceneEV,
            flashState: requestedFlashMode == .on ? .on : (requestedFlashMode == .auto ? .auto : .off),
            lensPosition: 0.5,
            orientation: orientation
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
                // Recipe built from the currently selected preset (U12 film flap)
                let defaultPreset = self.capturePreset
                let dimensions = rawData != nil ? resolvedSettings.rawPhotoDimensions : resolvedSettings.photoDimensions
                let swapsAxes = (5...8).contains(captureMetadata?.orientation ?? 1)
                let imageSize = CGSize(
                    width: CGFloat(swapsAxes ? dimensions.height : dimensions.width),
                    height: CGFloat(swapsAxes ? dimensions.width : dimensions.height)
                )
                let isLapse = CameraManager.isLapsePreset(defaultPreset)
                let recipe = RecipeVersion(
                    recipeID: defaultPreset.presetID,
                    presetDefinitionID: defaultPreset.id,
                    engineVersion: "1.0",
                    source: isLapse ? .processedHEVC : (rawData != nil ? .rawBayer : .processedHEVC),
                    parameters: RecipeVersion.Parameters(
                        filmPreset: defaultPreset.displayName,
                        filmStrength: 0.85,
                        exposureEV: 0.0,
                        temperatureK: 0.0,
                        tintOffset: 0.0,
                        contrastAmount: 1.0,
                        saturationAmount: 1.0
                    ),
                    crop: aspectRatio.crop(for: imageSize)
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
                        temperature: 4000,
                        tint: 0,
                        iso: 100,
                        exposureDuration: CMTime(value: 1, timescale: 60),
                        sceneEV: 8.0,
                        flashState: .auto,
                        lensPosition: 0.5,
                        orientation: 1
                    )
                )
                
                // Queue background rendering
                await MainActor.run {
                    DevelopmentQueue.shared.submit(
                        shot: shot,
                        preset: defaultPreset,
                        parameters: defaultPreset.baseParameters
                    )
                }
                
                completion(.success(shot))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
