import XCTest

final class TimerControlsUITests: XCTestCase {
    @MainActor
    func testAdjustmentsAndReset() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["startTime"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["startTime"].label, "Lead-in 3s")
        app.buttons["Increase lead-in by one second"].tap()
        XCTAssertEqual(app.staticTexts["startTime"].label, "Lead-in 4s")
        XCTAssertEqual(app.descendants(matching: .any)["elapsedTime"].value as? String, "−00:04.0")
        app.buttons["Decrease lead-in by one second"].tap()
        app.buttons["Increase set duration by five seconds"].tap()
        XCTAssertEqual(app.staticTexts["setDuration"].label, "45s")
        app.buttons["Decrease set duration by five seconds"].tap()
        XCTAssertEqual(app.staticTexts["setDuration"].label, "40s")
        app.buttons["startPause"].tap()
        XCTAssertFalse(app.buttons["Increase lead-in by one second"].isEnabled)
        app.buttons["Reset"].tap()
        XCTAssertEqual(app.buttons["startPause"].label, "Start")
        XCTAssertEqual(app.staticTexts["startTime"].label, "Lead-in 3s")
        XCTAssertTrue(app.buttons["Increase lead-in by one second"].isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Timer design"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testIntervalButtonsRespondAwayFromSymbols() {
        let app = XCUIApplication()
        app.launch()
        let decrease = app.buttons["Decrease set duration by five seconds"]
        let increase = app.buttons["Increase set duration by five seconds"]
        XCTAssertTrue(decrease.waitForExistence(timeout: 5))
        let corners = [
            CGVector(dx: 0.15, dy: 0.15), CGVector(dx: 0.85, dy: 0.15),
            CGVector(dx: 0.15, dy: 0.85), CGVector(dx: 0.85, dy: 0.85)
        ]
        for corner in corners {
            decrease.coordinate(withNormalizedOffset: corner).tap()
            XCTAssertEqual(app.staticTexts["setDuration"].label, "35s")
            increase.coordinate(withNormalizedOffset: corner).tap()
            XCTAssertEqual(app.staticTexts["setDuration"].label, "40s")
        }
    }

    @MainActor
    func testSetCountingToggle() {
        let app = XCUIApplication()
        app.launch()
        let toggle = app.switches["setCountingToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertEqual(app.staticTexts["currentSet"].label, "Set counting off")
        XCTAssertFalse(app.buttons["Increase set duration by five seconds"].isEnabled)
        app.buttons["startPause"].tap()
        XCTAssertEqual(app.buttons["startPause"].label, "Pause")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(app.buttons["startPause"].label, "Pause")
        XCTAssertFalse(app.buttons["Increase set duration by five seconds"].isEnabled)
        app.buttons["Reset"].tap()
        XCTAssertTrue(app.buttons["Increase set duration by five seconds"].isEnabled)
        XCTAssertEqual(app.staticTexts["setDuration"].label, "40s")
    }

    @MainActor
    func testSetAdvancesAfterLeadIn() {
        let app = XCUIApplication()
        app.launch()
        for _ in 0..<7 { app.buttons["Decrease set duration by five seconds"].tap() }
        XCTAssertEqual(app.staticTexts["setDuration"].label, "5s")
        app.buttons["startPause"].tap()
        XCTAssertEqual(app.staticTexts["currentSet"].label, "Set 1, 0 completed")
        XCTAssertEqual(app.descendants(matching: .any)["setIndicators"].value as? String, "1 set")
        let nextSet = NSPredicate(format: "label == %@", "Set 2, 1 completed")
        expectation(for: nextSet, evaluatedWith: app.staticTexts["currentSet"])
        waitForExpectations(timeout: 12)
        XCTAssertEqual(app.descendants(matching: .any)["setIndicators"].value as? String, "2 sets")
        app.buttons["Reset"].tap()
        XCTAssertEqual(app.staticTexts["currentSet"].label, "Set 1, 0 completed")
    }
}
