import Foundation

/// 주기적으로 `tick(now:)`을 불러 잠금 시각 도달 여부를 판정한다.
///
/// 타이머 대신 폴링 방식을 쓰는 이유: 잠자기·시계 변경이 있어도
/// 매 틱마다 "지금"을 기준으로 판단하므로 어긋나지 않는다.
public struct LockClock: Sendable {
    public enum Decision: Equatable, Sendable {
        /// 아직 잠금 시각이 아님.
        case wait
        /// 잠금 시각에 도달 → 잠가야 함.
        case fire
        /// 잠금 시각을 유예 시간 이상 지나서 알았음 (예: 맥이 잠자기 중이었음) → 소급 잠금하지 않음.
        case missed
    }

    public var schedule: WorkSchedule
    /// 잠금 시각이 지난 뒤 이 시간 안에 알아차리면 잠근다.
    public var grace: TimeInterval
    public private(set) var nextFire: Date?
    private let calendar: Calendar

    public init(schedule: WorkSchedule, now: Date, grace: TimeInterval = 120, calendar: Calendar = .current) {
        self.schedule = schedule
        self.grace = grace
        self.calendar = calendar
        self.nextFire = schedule.nextLock(after: now, calendar: calendar)
    }

    /// 설정이 바뀌었거나 시계가 바뀌었을 때 다음 잠금 시각을 다시 계산한다.
    public mutating func reschedule(now: Date) {
        nextFire = schedule.nextLock(after: now, calendar: calendar)
    }

    public mutating func update(schedule: WorkSchedule, now: Date) {
        self.schedule = schedule
        reschedule(now: now)
    }

    public mutating func tick(now: Date) -> Decision {
        guard let fire = nextFire else {
            reschedule(now: now)
            return .wait
        }
        guard now >= fire else { return .wait }

        reschedule(now: now)
        return now.timeIntervalSince(fire) <= grace ? .fire : .missed
    }
}

/// "오늘 하루 끄기" 판정.
public enum DaySkip {
    public static func isSkipped(_ skippedDay: Date?, on date: Date, calendar: Calendar = .current) -> Bool {
        guard let skippedDay else { return false }
        return calendar.isDate(skippedDay, inSameDayAs: date)
    }
}
