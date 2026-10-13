import AppKit
import AVFoundation
import NeckLockCore

/// 잠금 한 번의 생명주기: 입력 차단 + 카메라 창 → 회전 판정 → 해제.
///
/// 원칙: 잠그지 못하는 상황(권한 없음, 카메라 없음)에서는 **잠그지 않는다** (fail-open).
/// 입력만 막고 풀 방법이 없는 상태가 되는 것을 피하기 위해서다.
@MainActor
final class LockCoordinator {
    enum StartResult {
        case started
        case needsAccessibility
        case needsCamera
    }

    enum FinishReason {
        case completed
        case skippedToday
        case emergency
        case timeout
    }

    private let detector = HeadPoseDetector()
    private let blocker = InputBlocker()
    private let panel = LockPanelController()
    private var maxTimer: Timer?
    private var finishHandler: ((FinishReason) -> Void)?

    private(set) var isLocked = false

    func start(settings: AppSettings, onFinish: @escaping (FinishReason) -> Void) -> StartResult {
        guard !isLocked else { return .started }

        guard InputBlocker.hasPermission else {
            InputBlocker.requestPermission()
            return .needsAccessibility
        }
        guard HeadPoseDetector.isAuthorized, detector.configure() else {
            return .needsCamera
        }

        var config = RotationConfig()
        config.lapsRequired = settings.laps
        let model = LockViewModel(config: config, debug: settings.debugOverlay)
        model.onSkipToday = { [weak self] in self?.finish(.skippedToday) }
        model.onComplete = { [weak self] in self?.finish(.completed) }

        detector.onPose = { [weak model] pose in model?.ingest(pose) }
        blocker.onEmergency = { [weak self] in self?.finish(.emergency) }

        blocker.allowedRect = panel.show(model: model, session: detector.session)
        guard blocker.start() else {
            panel.close()
            detector.onPose = nil
            return .needsAccessibility
        }
        detector.start()

        isLocked = true
        finishHandler = onFinish

        if settings.maxLockMinutes > 0 {
            let seconds = TimeInterval(settings.maxLockMinutes * 60)
            maxTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.finish(.timeout) }
            }
        }
        return .started
    }

    private func finish(_ reason: FinishReason) {
        guard isLocked else { return }
        isLocked = false

        maxTimer?.invalidate()
        maxTimer = nil

        // 입력은 즉시 푼다. 완료 표시(체크)만 잠깐 더 보여준다.
        blocker.stop()
        detector.stop()
        detector.onPose = nil

        if reason == .completed {
            panel.close(after: 0.9)
        } else {
            panel.close()
        }

        let handler = finishHandler
        finishHandler = nil
        handler?(reason)
    }
}
