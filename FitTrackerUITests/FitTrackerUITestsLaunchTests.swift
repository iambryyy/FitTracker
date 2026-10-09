//
//  FitTrackerUITestsLaunchTests.swift
//  FitTrackerUITests
//
//  Created by Cris Briseno on 12/3/23.
//

import XCTest

final class FitTrackerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Leave the simulator the way the other test classes expect it.
        XCUIDevice.shared.orientation = .portrait
    }

    /// Runs once per UI configuration (such as light and dark appearance) and
    /// keeps a screenshot of the dashboard for each, as a visual smoke check.
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.uiTesting, LaunchArgument.resetState, LaunchArgument.seedProfile]
        app.launch()

        XCTAssertTrue(app.staticTexts[AccessibilityID.Dashboard.greeting].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dashboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
