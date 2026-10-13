import XCTest
@testable import NeckLockCore

final class RotationTrackerTests: XCTestCase {
    /// 머리 방향이 타원을 따라 도는 것을 흉내낸다. `amplitude`는 반지름 배율 (1.0 = 인식 경계).
    private func sweep(
        _ tracker: inout RotationTracker,
        fromDegrees start: Double,
        toDegrees end: Double,
        step: Double = 10,
        amplitude: Double = 1.6,
        direction: Double = 1
    ) {
        let config = tracker.config
        var a = start
        while a <= end {
            let r = a * .pi / 180
            tracker.update(with: HeadPose(
                yaw: cos(r) * config.yawRange * amplitude,
                pitch: direction * sin(r) * config.pitchRange * amplitude
            ))
            a += step
        }
    }

    func testOneRotationIsNotEnoughForTwoLaps() {
        var tracker = RotationTracker(config: RotationConfig(lapsRequired: 2))
        sweep(&tracker, fromDegrees: 0, toDegrees: 360)
        XCTAssertFalse(tracker.isComplete)
        XCTAssertEqual(tracker.completedLaps, 0)
        XCTAssertGreaterThan(tracker.totalProgress, 0.3)
    }

    func testEnoughRotationsCompleteTwoLaps() {
        var tracker = RotationTracker(config: RotationConfig(lapsRequired: 2))
        sweep(&tracker, fromDegrees: 0, toDegrees: 1200)
        XCTAssertTrue(tracker.isComplete)
        XCTAssertEqual(tracker.completedLaps, 2)
        XCTAssertEqual(tracker.totalProgress, 1, accuracy: 1e-9)
    }

    func testOneLapAfterOneAndAHalfRotations() {
        var tracker = RotationTracker(config: RotationConfig(lapsRequired: 2))
        sweep(&tracker, fromDegrees: 0, toDegrees: 540)
        XCTAssertEqual(tracker.completedLaps, 1)
        XCTAssertFalse(tracker.isComplete)
    }

    func testDirectionDoesNotMatter() {
        var tracker = RotationTracker(config: RotationConfig(lapsRequired: 2))
        sweep(&tracker, fromDegrees: 0, toDegrees: 1200, direction: -1)
        XCTAssertTrue(tracker.isComplete)
    }

    func testShakingLeftRightDoesNotProgress() {
        var tracker = RotationTracker(config: RotationConfig(lapsRequired: 1))
        let range = tracker.config.yawRange
        for i in 0..<400 {
            let yaw = (i / 10) % 2 == 0 ? range * 1.6 : -range * 1.6
            tracker.update(with: HeadPose(yaw: yaw, pitch: 0))
        }
        XCTAssertEqual(tracker.accumulated, 0, accuracy: 0.5)
        XCTAssertFalse(tracker.isComplete)
    }

    func testSmallMovementIsIgnored() {
        var tracker = RotationTracker(config: RotationConfig(lapsRequired: 1))
        sweep(&tracker, fromDegrees: 0, toDegrees: 1440, amplitude: 0.5)
        XCTAssertEqual(tracker.accumulated, 0)
        XCTAssertFalse(tracker.isEngaged)
    }

    func testFaceLossKeepsProgress() {
        var tracker = RotationTracker(config: RotationConfig(lapsRequired: 3))
        sweep(&tracker, fromDegrees: 0, toDegrees: 540)
        let before = tracker.accumulated
        XCTAssertGreaterThan(abs(before), 0)

        tracker.update(with: nil)
        XCTAssertEqual(tracker.accumulated, before)
        XCTAssertFalse(tracker.isEngaged)
        XCTAssertNil(tracker.vector)

        // 얼굴이 다시 잡히면 이어서 누적한다.
        sweep(&tracker, fromDegrees: 540, toDegrees: 900)
        XCTAssertGreaterThan(abs(tracker.accumulated), abs(before))
    }

    func testJumpsLargerThanMaxStepAreDiscarded() {
        var config = RotationConfig(lapsRequired: 1)
        config.smoothing = 1 // 평활화 끄기
        var tracker = RotationTracker(config: config)
        let y = config.yawRange * 2
        let p = config.pitchRange * 2
        tracker.update(with: HeadPose(yaw: y, pitch: 0))          // 0°
        tracker.update(with: HeadPose(yaw: -y, pitch: 0.001 * p)) // 약 180° 순간 이동 (튐)
        XCTAssertEqual(tracker.accumulated, 0, accuracy: 0.1)
    }

    func testWrap() {
        XCTAssertEqual(RotationTracker.wrap(3 * .pi), .pi, accuracy: 1e-9)
        XCTAssertEqual(RotationTracker.wrap(-3 * .pi), .pi, accuracy: 1e-9)
        XCTAssertEqual(RotationTracker.wrap(0.5), 0.5, accuracy: 1e-9)
    }
}
