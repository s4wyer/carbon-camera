import AVFoundation
import Photos
import os.log

/// Camera manager: AVFoundation session, capture, and device configuration
/// Implements D-002 baseline (Lapse camera config) with overrides
@MainActor
final class CameraManager: NSObject, ObservableObject {
    // MARK: - Published state
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var captureError: Error?
    @Published var lastCapturedPhoto: CapturedPhoto?
    
    // MARK: - Private state
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "app.carbon.camera.session")
    private let logger = Logger(subsystem: "app.carbon", category: "CameraManager")
    
    // Current settings (D-002 defaults)
    private var currentFocalLength: Double = 35.0  // D-002 override: 35mm default
    private var currentFlashMode: AVCaptureDevice.FlashMode = .auto  // D-002 override
    private var currentExposureBias: Float = 0.0  // MOOD dial value
    
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
    
    // MARK: - Session configuration (D-002 baseline)
    
    private func configureSession() {
        session.beginConfiguration()
        
        // Session preset: .photo (high quality, D-002)
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        // Add video device input
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
            
            // Configure photo output (D-002: RAW+HEVC when supported)
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            // Enable RAW+processed delivery (C04, D-002 override)
            if photoOutput.availableRawPhotoPixelFormatTypes.count > 0 {
                photoOutput.isAppleProRAWEnabled = photoOutput.isAppleProRAWSupported
            }
        }
        
        session.commitConfiguration()
        
        // Configure device (focus, exposure, white balance)
        configureDevice(device)
        
        // Start running
        session.startRunning()
        Task { @MainActor in
            self.isSessionRunning = true
        }
        
        logger.info("Camera session configured and started")
    }
    
    private func selectBestDevice() -> AVCaptureDevice? {
        // Prefer triple camera system, fall back to dual, then wide
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .back
        )
        
        return discoverySession.devices.first
    }
    
    /// Configure device: continuous AF/AE, locked white balance, input priority (D-002)
    private func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // D-002: Continuous autofocus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // D-002: Continuous auto-exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // D-002: Auto white balance (locked per Lapse config)
            if device.isWhiteBalanceModeSupported(.autoWhiteBalance) {
                device.whiteBalanceMode = .autoWhiteBalance
            }
            
            // D-002: .inputPriority session preset behavior (responsiveness over max quality)
            // Note: This is set via capture photo settings, not device property
            
            // Set initial zoom to 35mm equivalent
            setZoomForFocalLength(35.0, on: device)
            
            device.unlockForConfiguration()
        } catch {
            logger.error("Failed to configure device: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Zoom control (C10, D-025)
    
    func setZoom(for focalLength: Double) {
        currentFocalLength = focalLength
        
        guard let device = currentDevice else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                self.setZoomForFocalLength(focalLength, on: device)
                device.unlockForConfiguration()
            } catch {
                self.logger.error("Failed to set zoom: \(error.localizedDescription)")
            }
        }
    }
    
    private func setZoomForFocalLength(_ focalLength: Double, on device: AVCaptureDevice) {
        // Map 24/35/50mm to device zoom factors
        // This is approximate; actual mapping requires device-specific calibration
        let zoomFactor: CGFloat
        
        switch focalLength {
        case 24:
            zoomFactor = 1.0  // Ultra-wide
        case 35:
            zoomFactor = 1.5  // Mid-range (approximation)
        case 50:
            zoomFactor = 2.0  // Telephoto
        default:
            zoomFactor = 1.5
        }
        
        let clampedZoom = min(max(zoomFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        
        // D-025 / C10: Ramp over ~200ms (0.2 seconds)
        device.ramp(toVideoZoomFactor: clampedZoom, withRate: 10.0)
    }
    
    // MARK: - Exposure control (D-025 / R08)
    
    func setExposureBias(_ ev: Float) {
        currentExposureBias = ev
        
        guard let device = currentDevice else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                // Clamp to device limits
                let clampedEV = min(max(ev, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(clampedEV, completionHandler: nil)
                
                device.unlockForConfiguration()
            } catch {
                self.logger.error("Failed to set exposure bias: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Photo capture (C04, D-002, D-025)
    
    func capturePhoto() {
        guard isSessionRunning else {
            logger.warning("Capture requested but session not running")
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let settings = self.buildPhotoSettings()
            
            let delegate = PhotoCaptureDelegate { result in
                Task { @MainActor in
                    switch result {
                    case .success(let photo):
                        self.lastCapturedPhoto = photo
                        self.logger.info("Photo captured successfully")
                    case .failure(let error):
                        self.captureError = error
                        self.logger.error("Photo capture failed: \(error.localizedDescription)")
                    }
                }
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
    
    private func buildPhotoSettings() -> AVCapturePhotoSettings {
        var settings: AVCapturePhotoSettings
        
        // D-002 override: Capture RAW + HEVC when supported (C04)
        if photoOutput.availableRawPhotoPixelFormatTypes.count > 0,
           let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
            
            // RAW + processed HEVC
            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawFormat,
                processedFormat: [
                    AVVideoCodecKey: AVVideoCodecType.hevc,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoQualityKey: 0.95  // D-025 / SET11-q1
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
        
        // D-002 override: Auto flash
        if photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = currentFlashMode
        }
        
        // D-002: Quality prioritization
        settings.photoQualityPrioritization = .quality
        
        // Enable depth if available (M5 future work)
        settings.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliveryEnabled
        
        return settings
    }
}

// MARK: - Photo capture delegate

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<CapturedPhoto, Error>) -> Void
    
    init(completion: @escaping (Result<CapturedPhoto, Error>) -> Void) {
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
        
        // Extract photo data
        guard let processedData = photo.fileDataRepresentation() else {
            completion(.failure(CaptureError.noData))
            return
        }
        
        // Extract RAW if available
        var rawData: Data?
        if photo.isRawPhoto {
            rawData = processedData
        }
        
        let capturedPhoto = CapturedPhoto(
            processedData: processedData,
            rawData: rawData,
            timestamp: Date(),
            metadata: photo.metadata
        )
        
        completion(.success(capturedPhoto))
    }
}

// MARK: - Captured photo model

struct CapturedPhoto {
    let processedData: Data
    let rawData: Data?
    let timestamp: Date
    let metadata: [String: Any]
}

enum CaptureError: Error {
    case noData
    case sessionNotRunning
    case deviceUnavailable
}
