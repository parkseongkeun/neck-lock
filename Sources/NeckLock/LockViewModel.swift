import Foundation
import NeckLockCore

@MainActor
final class LockViewModel: ObservableObject {
    @Published private(set) var tracker: RotationTracker
    @Published private(set) var faceDetected = false
    @Published private(set) var lastPose: HeadPose?
    @Published private(set) var completed = false

    let lapsRequired: Int
    let debug: Bool

    var onSkipToday: (() -> Void)?
    var onComplete: (() -> Void)?

    init(config: RotationConfig, debug: Bool) {
        tracker = RotationTracker(config: config)
        lapsRequired = config.lapsRequired
        self.debug = debug
    }

    /// 프레임마다 호출. 얼굴이 없으면 nil.
    func ingest(_ pose: HeadPose?) {
        faceDetected = pose != nil
        lastPose = pose
        guard !completed else { return }

        tracker.update(with: pose)
        if tracker.isComplete {
            completed = true
            onComplete?()
        }
    }
}
