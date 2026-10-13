import XCTest
@testable import NeckLockCore

final class LockMakeupTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }

    private func date(_ h: Int, _ m: Int, day: Int = 14) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m))!
    }

    func testDueWithinTheSameHour() {
        XCTAssertTrue(LockMakeup.isDue(skippedAt: date(11, 0), now: date(11, 0), calendar: calendar))
        XCTAssertTrue(LockMakeup.isDue(skippedAt: date(11, 0), now: date(11, 40), calendar: calendar))
        XCTAssertTrue(LockMakeup.isDue(skippedAt: date(11, 0), now: date(11, 59), calendar: calendar))
    }

    func testNotDueOnceTheHourHasPassed() {
        XCTAssertFalse(LockMakeup.isDue(skippedAt: date(11, 0), now: date(12, 0), calendar: calendar))
        XCTAssertFalse(LockMakeup.isDue(skippedAt: date(11, 0), now: date(14, 5), calendar: calendar))
    }

    func testNotDueTheNextDayAtTheSameHour() {
        XCTAssertFalse(LockMakeup.isDue(skippedAt: date(11, 0), now: date(11, 30, day: 15), calendar: calendar))
    }

    func testNotDueBeforeTheSkippedTime() {
        XCTAssertFalse(LockMakeup.isDue(skippedAt: date(11, 0), now: date(10, 59), calendar: calendar))
    }
}
