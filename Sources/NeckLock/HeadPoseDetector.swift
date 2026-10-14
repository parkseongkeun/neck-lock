import AVFoundation
import Vision
import NeckLockCore

/// 카메라 프레임에서 Vision으로 머리 방향(yaw, pitch)을 읽는다.
///
/// - 누구 얼굴이든 상관없다. 가장 큰 얼굴 하나만 쓴다.
/// - Revision 3부터 yaw/pitch가 연속값(라디안)으로 나온다.
final class HeadPoseDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()

    /// 프레임마다 메인 액터에서 호출. 얼굴이 없으면 nil.
    var onPose: (@MainActor (HeadPose?) -> Void)?

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "necklock.camera")
    private var configured = false

    /// 카메라 권한을 요청한다. 이미 결정돼 있으면 바로 결과를 돌려준다.
    static func requestAccess(completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in completion(granted) }
        default:
            completion(false)
        }
    }

    static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// 지금 세션에 연결된 카메라.
    private(set) var currentDevice: AVCaptureDevice?

    /// 선택 가능한 카메라 (내장, 외장 웹캠, 아이폰 연속성 카메라).
    static func availableCameras() -> [AVCaptureDevice] {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            types += [.external, .continuityCamera]
        } else {
            types.append(.externalUnknown)
        }
        return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified).devices
    }

    /// 고른 카메라(없으면 시스템 기본)를 연다. 고른 카메라가 없으면 기본으로 대체한다.
    private static func resolve(_ preferredID: String?) -> AVCaptureDevice? {
        if let preferredID, let device = AVCaptureDevice(uniqueID: preferredID) { return device }
        return AVCaptureDevice.default(for: .video)
    }

    /// 세션을 구성한다. 카메라가 없거나 열 수 없으면 false.
    func configure(preferredID: String? = nil) -> Bool {
        guard let device = Self.resolve(preferredID) else { return false }
        if configured, currentDevice?.uniqueID == device.uniqueID { return true }
        return install(device)
    }

    /// 잠금 중에 다른 카메라로 바꾼다. 실패하면 원래 카메라를 유지하고 false.
    func switchCamera(to id: String) -> Bool {
        guard let device = AVCaptureDevice(uniqueID: id) else { return false }
        if currentDevice?.uniqueID == device.uniqueID { return true }
        return install(device)
    }

    private func install(_ device: AVCaptureDevice) -> Bool {
        guard let input = try? AVCaptureDeviceInput(device: device) else { return false }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let previous = session.inputs
        previous.forEach { session.removeInput($0) }
        guard session.canAddInput(input) else {
            previous.forEach { session.addInput($0) }   // 실패하면 원래대로
            return false
        }
        session.addInput(input)
        if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }

        if session.outputs.isEmpty {
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { return false }
            session.addOutput(output)
        }

        currentDevice = device
        configured = true
        return true
    }

    func start() {
        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        var pose: HeadPose?
        if (try? handler.perform([request])) != nil,
           let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
           let yaw = face.yaw?.doubleValue {
            pose = HeadPose(yaw: yaw, pitch: face.pitch?.doubleValue ?? 0)
        }

        let result = pose
        Task { @MainActor [weak self] in
            self?.onPose?(result)
        }
    }
}
