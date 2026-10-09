//
//  FitTrackerUITestCase.swift
//  FitTrackerUITests
//

import XCTest

/// Base class for every UI test. Each test launches the app in UI-testing mode:
/// isolated storage, the offline food database, and animations off.
class FitTrackerUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // The launch test rotates the device; every other test assumes portrait.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    /// Launches (or relaunches) the app.
    /// - Parameters:
    ///   - reset: Wipe saved data first. Pass `false` to test persistence across launches.
    ///   - seedProfile: Skip onboarding with the built-in sample profile.
    ///   - searchMode: Which food search backend the app should use.
    func launch(reset: Bool = true, seedProfile: Bool = true, searchMode: SearchMode = .offline) {
        var arguments = [LaunchArgument.uiTesting]
        if reset { arguments.append(LaunchArgument.resetState) }
        if seedProfile { arguments.append(LaunchArgument.seedProfile) }
        app.launchArguments = arguments
        app.launchEnvironment[LaunchEnvironmentKey.searchMode] = searchMode.rawValue
        app.launch()
    }
}

extension XCUIElement {
    /// Fails the test with a readable message if the element never appears.
    @discardableResult
    func assertExists(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(waitForExistence(timeout: timeout), "Expected \(self) to exist", file: file, line: line)
        return self
    }

    func assertGone(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected \(self) to disappear", file: file, line: line)
    }

    /// Waits until the element's label equals `expected`, then asserts it.
    func assertLabel(_ expected: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        assertExists(timeout: timeout, file: file, line: line)
        let matches = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: matches, object: self)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(label, expected, file: file, line: line)
    }

    /// Replaces whatever is in a text field with `text`.
    func replaceText(with text: String) {
        // Tap at the trailing edge so the cursor lands after the last character.
        coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let existing = (value as? String) ?? ""
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)
        typeText(deletes + text)
    }
}

extension XCUIApplication {
    /// Finds an element by accessibility identifier regardless of its type.
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
