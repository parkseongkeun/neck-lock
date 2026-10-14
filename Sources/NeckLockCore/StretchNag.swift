import Foundation

/// 잠긴 뒤 스트레칭을 안 하고 있는지 판정한다. 안 하고 있으면 경고(빨간 테두리)를 켠다.
///
/// "하고 있다" = 마지막 확인 이후 회전 누적량이 조금이라도 늘었다.
/// 크게 돌린 채 가만히 있거나 얼굴이 안 보이는 상태는 "안 하고 있다"로 본다.
public struct StretchNag: Sendable {
    /// 이만큼 움직임이 없으면 경고를 시작한다.
    public let graceSeconds: TimeInterval
    /// 이 각도(라디안) 이상 누적량이 늘어야 움직임으로 인정한다. (기본 1°)
    public let minProgress: Double

    public private(set) var isNagging = false
    private var lastActivity: Date
    private var lastAccumulated: Double = 0

    public init(startedAt: Date, graceSeconds: TimeInterval = 20, minProgress: Double = .pi / 180) {
        self.lastActivity = startedAt
        self.graceSeconds = graceSeconds
        self.minProgress = minProgress
    }

    /// 경고가 시작되기까지 남은 초. 이미 경고 중이면 0.
    public func secondsUntilNag(now: Date) -> TimeInterval {
        max(0, graceSeconds - now.timeIntervalSince(lastActivity))
    }

    /// 주기적으로 호출. 경고를 켜야 하면 true.
    @discardableResult
    public mutating func update(now: Date, tracker: RotationTracker) -> Bool {
        let accumulated = abs(tracker.accumulated)
        if abs(accumulated - lastAccumulated) >= minProgress {
            lastAccumulated = accumulated
            lastActivity = now
        }
        isNagging = !tracker.isComplete && now.timeIntervalSince(lastActivity) >= graceSeconds
        return isNagging
    }
}
