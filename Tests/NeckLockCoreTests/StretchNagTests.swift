import XCTest
@testable import NeckLockCore

final class StretchNagTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func rotate(_ tracker: inout RotationTracker, degrees: Double) {
        let c = tracker.config
        var a = 0.0
        while a <= degrees {
            let r = a * .pi / 180
            tracker.update(with: HeadPose(yaw: cos(r) * c.yawRange * 1.6, pitch: sin(r) * c.pitchRange * 1.6))
            a += 10
        }
    }

    func testNoNagBeforeGrace() {
        var nag = StretchNag(startedAt: start, graceSeconds: 20)
        let tracker = RotationTracker()
        XCTAssertFalse(nag.update(now: start.addingTimeInterval(19), tracker: tracker))
    }

    func testNagStartsAfterGraceWithNoMovement() {
        var nag = StretchNag(startedAt: start, graceSeconds: 20)
        let tracker = RotationTracker()
        XCTAssertTrue(nag.update(now: start.addingTimeInterval(20), tracker: tracker))
        XCTAssertTrue(nag.isNagging)
    }

    func testMovementStopsNagAndRestartsGrace() {
        var nag = StretchNag(startedAt: start, graceSeconds: 20)
        var tracker = RotationTracker()
        XCTAssertTrue(nag.update(now: start.addingTimeInterval(25), tracker: tracker))
        rotate(&tracker, degrees: 120)
        XCTAssertFalse(nag.update(now: start.addingTimeInterval(26), tracker: tracker))
        XCTAssertFalse(nag.update(now: start.addingTimeInterval(45), tracker: tracker))   // 움직임 후 19초
        XCTAssertTrue(nag.update(now: start.addingTimeInterval(46), tracker: tracker))    // 20초 → 다시 시작
    }

    func testHoldingStillWhileEngagedStillNags() {
        var nag = StretchNag(startedAt: start, graceSeconds: 20)
        var tracker = RotationTracker()
        rotate(&tracker, degrees: 90)
        nag.update(now: start.addingTimeInterval(1), tracker: tracker)
        XCTAssertTrue(tracker.isEngaged)
        XCTAssertTrue(nag.update(now: start.addingTimeInterval(30), tracker: tracker))
    }

    func testNeverNagsAfterCompletion() {
        var nag = StretchNag(startedAt: start, graceSeconds: 20)
        var tracker = RotationTracker(config: RotationConfig(lapsRequired: 1))
        rotate(&tracker, degrees: 500)
        XCTAssertTrue(tracker.isComplete)
        XCTAssertFalse(nag.update(now: start.addingTimeInterval(500), tracker: tracker))
    }
}
