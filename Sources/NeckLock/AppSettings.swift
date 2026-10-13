import Foundation
import NeckLockCore

/// UserDefaults에 저장되는 앱 설정. 값이 바뀌면 즉시 저장한다.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let schedule = "schedule"
        static let laps = "laps"
        static let maxLockMinutes = "maxLockMinutes"
        static let debugOverlay = "debugOverlay"
        static let skippedDay = "skippedDay"
    }

    private let defaults = UserDefaults.standard

    @Published var schedule: WorkSchedule {
        didSet {
            if let data = try? JSONEncoder().encode(schedule) {
                defaults.set(data, forKey: Key.schedule)
            }
        }
    }

    /// 해제에 필요한 바퀴 수.
    @Published var laps: Int {
        didSet { defaults.set(laps, forKey: Key.laps) }
    }

    /// 이 시간이 지나면 잠금을 자동으로 푼다 (버그로 맥을 못 쓰게 되는 상황 방지). 0 = 제한 없음.
    @Published var maxLockMinutes: Int {
        didSet { defaults.set(maxLockMinutes, forKey: Key.maxLockMinutes) }
    }

    /// 잠금 창에 yaw/pitch/누적 각도를 표시 (민감도 튜닝용).
    @Published var debugOverlay: Bool {
        didSet { defaults.set(debugOverlay, forKey: Key.debugOverlay) }
    }

    /// "오늘 하루 끄기"를 누른 날. 날짜가 바뀌면 자동으로 무효가 된다.
    var skippedDay: Date? {
        get { defaults.object(forKey: Key.skippedDay) as? Date }
        set { defaults.set(newValue, forKey: Key.skippedDay) }
    }

    private init() {
        if let data = defaults.data(forKey: Key.schedule),
           let saved = try? JSONDecoder().decode(WorkSchedule.self, from: data) {
            schedule = saved
        } else {
            schedule = .standard
        }

        let savedLaps = defaults.integer(forKey: Key.laps)
        laps = savedLaps > 0 ? savedLaps : 2

        maxLockMinutes = defaults.object(forKey: Key.maxLockMinutes) == nil
            ? 10
            : defaults.integer(forKey: Key.maxLockMinutes)

        debugOverlay = defaults.bool(forKey: Key.debugOverlay)
    }
}
