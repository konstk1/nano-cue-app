import XCTest
@testable import NanoCue

final class NanoCueTests: XCTestCase {
    @MainActor
    func testLeadInAdjustmentsAndBounds() {
        let timer = CuedTimer(audioEnabled: false)
        XCTAssertEqual(timer.elapsedTime, "−00:03.0")
        timer.adjustLeadIn(by: 1)
        XCTAssertEqual(timer.elapsedTime, "−00:04.0")
        timer.adjustLeadIn(by: -1)
        XCTAssertEqual(timer.elapsedTime, "−00:03.0")
        timer.adjustLeadIn(by: -100)
        XCTAssertEqual(timer.elapsedTime, "00:00.0")
        timer.adjustLeadIn(by: 100)
        XCTAssertEqual(timer.leadInSeconds, 60)
    }

    @MainActor
    func testSetDurationStepsAndBounds() {
        let timer = CuedTimer(audioEnabled: false)
        timer.adjustSetDuration(by: 1)
        XCTAssertEqual(timer.setDurationSeconds, 45)
        timer.adjustSetDuration(by: -1)
        XCTAssertEqual(timer.setDurationSeconds, 40)
        timer.adjustSetDuration(by: -100)
        XCTAssertEqual(timer.setDurationSeconds, 5)
        timer.adjustSetDuration(by: 1000)
        XCTAssertEqual(timer.setDurationSeconds, 600)
    }

    @MainActor
    func testSetsExcludeLeadInAndAdvanceAtBoundaries() {
        let timer = CuedTimer(audioEnabled: false)
        XCTAssertEqual(timer.completedSets, 0)
        XCTAssertEqual(timer.currentSet, 1)
        timer.elapsed = .seconds(39.9)
        XCTAssertEqual(timer.currentSet, 1)
        timer.elapsed = .seconds(40)
        XCTAssertEqual(timer.completedSets, 1)
        XCTAssertEqual(timer.currentSet, 2)
        timer.elapsed = .seconds(100)
        XCTAssertEqual(timer.completedSets, 2)
        XCTAssertEqual(timer.currentSet, 3)
        timer.elapsed = .seconds(400)
        XCTAssertEqual(timer.currentSet, 11)
    }

    @MainActor
    func testSetCountingTogglePreservesTimerAndInterval() {
        var instant = ContinuousClock.now
        let timer = CuedTimer(now: { instant }, audioEnabled: false)
        timer.adjustSetDuration(by: 1)
        timer.isSetCountingEnabled = false
        timer.adjustSetDuration(by: 1)
        XCTAssertEqual(timer.setDurationSeconds, 45)
        timer.start()
        instant += .seconds(103)
        timer.stop()
        XCTAssertEqual(CuedTimer.seconds(for: timer.elapsed), 100, accuracy: 0.001)
        XCTAssertEqual(timer.completedSets, 0)
        timer.isSetCountingEnabled = true
        XCTAssertEqual(timer.currentSet, 3)
        timer.isSetCountingEnabled = false
        timer.reset()
        XCTAssertFalse(timer.isSetCountingEnabled)
        XCTAssertEqual(timer.setDurationSeconds, 45)
        XCTAssertEqual(timer.elapsedTime, "−00:03.0")
    }

    @MainActor
    func testSignedFormattingAcrossZeroAndMinute() {
        let timer = CuedTimer(audioEnabled: false)
        for (seconds, expected) in [(-60.0, "−01:00.0"), (-0.5, "−00:00.5"),
                                    (0, "00:00.0"), (59.99, "00:59.9"), (60, "01:00.0")] {
            timer.elapsed = .seconds(seconds)
            XCTAssertEqual(timer.elapsedTime, expected)
        }
    }

    @MainActor
    func testZeroCrossingTicksOnceAndRegularCuesContinue() {
        let timer = CuedTimer(audioEnabled: false)
        timer.reset()
        timer.elapsed = .seconds(-0.01)
        XCTAssertNil(timer.nextCue())
        timer.elapsed = .zero
        XCTAssertEqual(timer.nextCue(), .tick)
        XCTAssertNil(timer.nextCue())
        timer.elapsed = .seconds(0.12)
        XCTAssertNil(timer.nextCue())
        timer.elapsed = .seconds(5.2)
        XCTAssertEqual(timer.nextCue(), .tick)
        timer.elapsed = .seconds(10.2)
        XCTAssertEqual(timer.nextCue(), .speech("10"))
        timer.elapsed = .seconds(60.2)
        XCTAssertEqual(timer.nextCue(), .speech("1 minute"))
    }

    @MainActor
    func testPauseResumeResetAndLockedConfiguration() async {
        var instant = ContinuousClock.now
        let timer = CuedTimer(now: { instant }, audioEnabled: false)
        timer.start()
        instant += .seconds(1)
        timer.stop()
        XCTAssertEqual(CuedTimer.seconds(for: timer.elapsed), -2, accuracy: 0.001)
        timer.adjustLeadIn(by: -1)
        timer.adjustSetDuration(by: 1)
        XCTAssertEqual(timer.leadInSeconds, 3)
        XCTAssertEqual(timer.setDurationSeconds, 40)
        instant += .seconds(20)
        timer.start()
        instant += .seconds(42)
        timer.stop()
        XCTAssertEqual(CuedTimer.seconds(for: timer.elapsed), 40, accuracy: 0.001)
        XCTAssertEqual(timer.currentSet, 2)
        timer.start()
        timer.reset()
        await Task.yield()
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.hasStarted)
        XCTAssertEqual(timer.elapsedTime, "−00:03.0")
        XCTAssertEqual(timer.currentSet, 1)
    }
}
