import SwiftUI
import AVFoundation
import NeckLockCore

/// 잠금 중에 화면 가운데 뜨는 카메라 창의 내용. (토스 얼굴인증 느낌: 원형 프리뷰 + 진행률 링)
struct LockView: View {
    @ObservedObject var model: LockViewModel
    let session: AVCaptureSession

    private let diameter: CGFloat = 240
    private var tracker: RotationTracker { model.tracker }

    var body: some View {
        VStack(spacing: 16) {
            Text("목 스트레칭 시간")
                .font(.title3.weight(.semibold))

            ZStack {
                CameraPreview(session: session)
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())

                ProgressRing(
                    side: diameter + 24,
                    lapProgress: tracker.lapProgress,
                    completedLaps: tracker.completedLaps,
                    direction: tracker.direction,
                    trailAngle: tracker.trailAngle,
                    headAngle: model.faceDetected ? tracker.headAngle : nil,
                    isEngaged: tracker.isEngaged,
                    completed: model.completed
                )

                if model.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.green)
                        .background(Circle().fill(.white).padding(8))
                }
            }
            .frame(width: diameter + 40, height: diameter + 40)

            Text("\(shownLaps) / \(model.lapsRequired) 바퀴")
                .font(.headline)
                .monospacedDigit()

            Text(hint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 40)

            if model.debug {
                Text(debugText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Button("오늘 하루 끄기") { model.onSkipToday?() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 360, height: 540)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.regularMaterial))
    }

    private var shownLaps: Int {
        model.completed ? model.lapsRequired : tracker.completedLaps
    }

    private var hint: String {
        if model.completed { return "완료! 이제 다시 쓸 수 있어요" }
        if !model.faceDetected { return "얼굴을 원 안에 맞춰주세요" }
        if tracker.isEngaged { return "좋아요, 그대로 계속 크게 돌려주세요" }
        if tracker.totalProgress > 0 { return "이어서 목을 크게 돌려주세요" }
        return "목을 천천히 크게 한 바퀴 돌려주세요\n(귀를 어깨에 닿게 한다는 느낌으로)"
    }

    private var debugText: String {
        let deg = 180 / Double.pi
        let yaw = (model.lastPose?.yaw ?? 0) * deg
        let pitch = (model.lastPose?.pitch ?? 0) * deg
        let acc = tracker.accumulated * deg
        let state = tracker.isEngaged ? "ON" : "off"
        return String(format: "yaw %+.0f°  pitch %+.0f°  누적 %+.0f°  ", yaw, pitch, acc) + state
    }
}

/// AVCaptureVideoPreviewLayer를 SwiftUI에 넣는 래퍼. 거울처럼 좌우 반전해서 보여준다.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}
}

final class PreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        layer = previewLayer
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
