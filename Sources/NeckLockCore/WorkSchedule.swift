import Foundation

/// 업무 시간 설정과, 그로부터 계산되는 잠금 시각.
///
/// 잠금 규칙 (PRD §3, §6):
/// - 업무 시작 정각은 잠그지 않는다 (아직 1시간을 일하지 않았으므로).
/// - 업무 종료 정각은 잠그지 않는다 (퇴근 시각).
/// - 점심 시작 정각 ~ 점심 종료 정각은 잠그지 않는다 (12:00, 13:00 모두 제외).
///
/// 기본값(평일 9–17시, 점심 12–13시)이면 잠금 시각은 10, 11, 14, 15, 16시 — 하루 5회.
public struct WorkSchedule: Codable, Equatable, Sendable {
    /// `Calendar` 요일 번호 (1 = 일요일 … 7 = 토요일).
    public var weekdays: Set<Int>
    public var startHour: Int
    public var endHour: Int
    public var lunchStartHour: Int
    public var lunchEndHour: Int

    public init(
        weekdays: Set<Int>,
        startHour: Int,
        endHour: Int,
        lunchStartHour: Int,
        lunchEndHour: Int
    ) {
        self.weekdays = weekdays
        self.startHour = startHour
        self.endHour = endHour
        self.lunchStartHour = lunchStartHour
        self.lunchEndHour = lunchEndHour
    }

    /// 평일(월–금) 09:00–17:00, 점심 12:00–13:00.
    public static let standard = WorkSchedule(
        weekdays: [2, 3, 4, 5, 6],
        startHour: 9,
        endHour: 17,
        lunchStartHour: 12,
        lunchEndHour: 13
    )

    /// 하루 중 잠기는 시(hour) 목록, 오름차순.
    public var lockHours: [Int] {
        let start = max(0, startHour)
        let end = min(24, endHour)
        guard start < end else { return [] }
        return ((start + 1)..<end).filter { hour in
            !(hour >= lunchStartHour && hour <= lunchEndHour)
        }
    }

    /// `date` 이후(같은 시각은 제외) 가장 가까운 잠금 시각. 잠글 시각이 없으면 nil.
    public func nextLock(after date: Date, calendar: Calendar = .current) -> Date? {
        let hours = lockHours
        guard !hours.isEmpty, !weekdays.isEmpty else { return nil }

        let today = calendar.startOfDay(for: date)
        // 오늘 포함 8일을 보면 어떤 요일 조합이든 반드시 찾는다.
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            guard weekdays.contains(calendar.component(.weekday, from: day)) else { continue }
            for hour in hours {
                guard let candidate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else {
                    continue
                }
                if candidate > date { return candidate }
            }
        }
        return nil
    }
}
