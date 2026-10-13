import XCTest
@testable import NeckLockCore

final class WorkScheduleTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    func testStandardLockHours() {
        XCTAssertEqual(WorkSchedule.standard.lockHours, [10, 11, 14, 15, 16])
    }

    func testEmptyWhenStartNotBeforeEnd() {
        var s = WorkSchedule.standard
        s.startHour = 17
        s.endHour = 9
        XCTAssertEqual(s.lockHours, [])
        XCTAssertNil(s.nextLock(after: date(2026, 10, 12, 9), calendar: calendar))
    }

    func testNextLockSameDay() {
        // 2026-10-12 = 월요일
        let next = WorkSchedule.standard.nextLock(after: date(2026, 10, 12, 9, 30), calendar: calendar)
        XCTAssertEqual(next, date(2026, 10, 12, 10))
    }

    func testExactLockTimeMovesToNext() {
        let next = WorkSchedule.standard.nextLock(after: date(2026, 10, 12, 11), calendar: calendar)
        XCTAssertEqual(next, date(2026, 10, 12, 14))
    }

    func testLunchIsSkipped() {
        let next = WorkSchedule.standard.nextLock(after: date(2026, 10, 12, 11, 30), calendar: calendar)
        XCTAssertEqual(next, date(2026, 10, 12, 14))
    }

    func testFridayEveningRollsToMonday() {
        // 2026-10-16 = 금요일
        let next = WorkSchedule.standard.nextLock(after: date(2026, 10, 16, 16, 30), calendar: calendar)
        XCTAssertEqual(next, date(2026, 10, 19, 10))
    }

    func testWeekendRollsToMonday() {
        // 2026-10-17 = 토요일
        let next = WorkSchedule.standard.nextLock(after: date(2026, 10, 17, 11), calendar: calendar)
        XCTAssertEqual(next, date(2026, 10, 19, 10))
    }

    func testClockFiresWithinGrace() {
        var clock = LockClock(schedule: .standard, now: date(2026, 10, 12, 9, 59), calendar: calendar)
        XCTAssertEqual(clock.tick(now: date(2026, 10, 12, 9, 59, 50)), .wait)
        XCTAssertEqual(clock.tick(now: date(2026, 10, 12, 10, 0, 5)), .fire)
        XCTAssertEqual(clock.nextFire, date(2026, 10, 12, 11))
        // 같은 시각에 두 번 울리지 않는다.
        XCTAssertEqual(clock.tick(now: date(2026, 10, 12, 10, 0, 15)), .wait)
    }

    func testClockMissedAfterSleep() {
        var clock = LockClock(schedule: .standard, now: date(2026, 10, 12, 9, 50), calendar: calendar)
        // 9:50에 잠들었다가 10:40에 깨어남 → 소급 잠금 안 함.
        XCTAssertEqual(clock.tick(now: date(2026, 10, 12, 10, 40)), .missed)
        XCTAssertEqual(clock.nextFire, date(2026, 10, 12, 11))
    }

    func testDaySkip() {
        let skipped = date(2026, 10, 12, 10, 5)
        XCTAssertTrue(DaySkip.isSkipped(skipped, on: date(2026, 10, 12, 16), calendar: calendar))
        XCTAssertFalse(DaySkip.isSkipped(skipped, on: date(2026, 10, 13, 10), calendar: calendar))
        XCTAssertFalse(DaySkip.isSkipped(nil, on: date(2026, 10, 12, 10), calendar: calendar))
    }
}
