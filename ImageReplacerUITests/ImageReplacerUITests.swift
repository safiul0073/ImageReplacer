import XCTest

final class ImageReplacerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainWindowLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Image Replacer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Scan Folders"].exists)
        XCTAssertTrue(app.buttons["Replace Images"].exists)
        XCTAssertTrue(app.staticTexts["Choose Source Images"].exists)
        XCTAssertTrue(app.staticTexts["Choose Destination Images"].exists)
    }

    func testReplaceStartsDisabledWithoutMappings() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.buttons["Replace Images"].isEnabled)
    }
}
