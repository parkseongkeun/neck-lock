import Foundation

/// 맥 화면이 잠겨 있어서 건너뛴 정각 잠금을, 화면이 풀린 직후 보충해서 걸지 판단한다.
///
/// 건너뛴 정각과 **같은 시간대(예: 11:00~11:59)** 안에 풀렸을 때만 보충한다.
/// 시간대가 지났으면 다음 잠금 시각이나 점심·퇴근과 겹칠 수 있으므로 포기한다.
public enum LockMakeup {
    public static func isDue(skippedAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        guard now >= skippedAt,
              let hour = calendar.dateInterval(of: .hour, for: skippedAt)
        else { return false }
        return now < hour.end   // DateInterval.contains는 끝 시각을 포함하므로 직접 비교한다
    }
}
