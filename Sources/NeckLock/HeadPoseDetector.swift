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

    /// 세션을 구성한다. 카메라가 없거나 열 수 없으면 false.
    func configure() -> Bool {
        if configured { return true }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return false
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .vga640x480
        guard session.canAddInput(input) else { return false }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)

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
