import AppKit
import AVFoundation
import NeckLockCore
import os

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

    private static let log = Logger(subsystem: "com.opensmartyouth.necklock", category: "lock")

    private let detector = HeadPoseDetector()
    private let blocker = InputBlocker()
    private let panel = LockPanelController()
    private let alarm = BorderAlarmController()
    private let dim = ScreenDimController()
    private var maxTimer: Timer?
    private var nagTimer: Timer?
    private var nag = StretchNag(startedAt: Date())
    private var model: LockViewModel?
    private var settings: AppSettings?
    private var finishHandler: ((FinishReason) -> Void)?

    private(set) var isLocked = false

    func start(settings: AppSettings, onFinish: @escaping (FinishReason) -> Void) -> StartResult {
        guard !isLocked else { return .started }

        guard InputBlocker.hasPermission else {
            InputBlocker.requestPermission()
            return .needsAccessibility
        }
        guard HeadPoseDetector.isAuthorized, detector.configure(preferredID: settings.cameraID) else {
            return .needsCamera
        }

        var config = RotationConfig()
        config.lapsRequired = settings.laps
        let model = LockViewModel(config: config, debug: settings.debugOverlay)
        model.onSkipToday = { [weak self] in self?.finish(.skippedToday) }
        model.onComplete = { [weak self] in self?.finish(.completed) }
        model.onSwitchCamera = { [weak self] in self?.cycleCamera() }
        refreshCameraInfo(on: model)

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
        self.model = model
        self.settings = settings

        if settings.dimEnabled { dim.show() }

        Self.log.info("잠금 시작 — 방치 경고 \(settings.nagEnabled ? "켬" : "끔"), 화면 어둡게 \(settings.dimEnabled ? "켬" : "끔"), 카메라 \(self.detector.currentDevice?.localizedName ?? "?")")

        if settings.nagEnabled {
            nag = StretchNag(startedAt: Date())
            model.nagRemaining = Int(nag.graceSeconds)
            nagTimer = Self.commonModeTimer(interval: 0.5, repeats: true) { [weak self] in self?.tickNag() }
        }

        if settings.maxLockMinutes > 0 {
            let seconds = TimeInterval(settings.maxLockMinutes * 60)
            maxTimer = Self.commonModeTimer(interval: seconds, repeats: false) { [weak self] in self?.finish(.timeout) }
        }
        return .started
    }

    /// 설정 화면·메뉴에서 붉은 테두리 모양을 미리 본다. 잠금 중에는 하지 않는다.
    func previewAlarm() {
        guard !isLocked else { return }
        alarm.preview()
    }

    /// 타이머는 메뉴를 연 채여도 돌아야 하므로 common 모드에 등록한다.
    private static func commonModeTimer(
        interval: TimeInterval,
        repeats: Bool,
        _ action: @escaping @MainActor () -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
            Task { @MainActor in action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func tickNag() {
        guard isLocked, let model else { return }
        let now = Date()
        let wasShowing = alarm.isShowing
        if nag.update(now: now, tracker: model.tracker) {
            alarm.show()
            model.nagRemaining = 0
        } else {
            alarm.hide()
            model.nagRemaining = Int(nag.secondsUntilNag(now: now).rounded(.up))
        }
        if wasShowing != alarm.isShowing {
            Self.log.info("방치 경고 \(self.alarm.isShowing ? "켜짐" : "꺼짐")")
        }
    }

    // MARK: - 카메라 전환

    private func refreshCameraInfo(on model: LockViewModel) {
        model.cameraCount = HeadPoseDetector.availableCameras().count
        model.cameraName = detector.currentDevice?.localizedName ?? ""
    }

    /// 잠금 창의 버튼: 다음 카메라로 돌려가며 바꾼다. 선택은 설정에 저장된다.
    private func cycleCamera() {
        guard isLocked, let model, let settings else { return }
        let cameras = HeadPoseDetector.availableCameras()
        guard cameras.count > 1 else { return }
        let currentID = detector.currentDevice?.uniqueID
        let index = cameras.firstIndex { $0.uniqueID == currentID } ?? -1
        let next = cameras[(index + 1) % cameras.count]
        if detector.switchCamera(to: next.uniqueID) {
            settings.cameraID = next.uniqueID
            Self.log.info("카메라 전환 → \(next.localizedName)")
        }
        refreshCameraInfo(on: model)
    }

    private func finish(_ reason: FinishReason) {
        guard isLocked else { return }
        isLocked = false
        Self.log.info("잠금 종료 — \(String(describing: reason))")

        nagTimer?.invalidate()
        nagTimer = nil
        alarm.hide()
        dim.hide()
        model = nil
        settings = nil

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
