//
//  ScreenshotTourUITests.swift
//  FitTrackerUITests
//

import XCTest

/// Walks the main flow and keeps a screenshot of each screen in the result
/// bundle. The README images are exported from this test's attachments.
final class ScreenshotTourUITests: FitTrackerUITestCase {

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTourOfEveryScreen() {
        launch(seedProfile: false)
        let onboarding = OnboardingScreen(app: app)
        onboarding.form.fillMetric(name: "Alex", heightCm: "180", weightKg: "80")
        onboarding.form.goalPreview.assertExists()
        capture("1-onboarding")
        onboarding.submitButton.tap()

        let dashboard = DashboardScreen(app: app)
        dashboard.greeting.assertExists()
        dashboard.logFood("oatmeal")
        dashboard.logFood("banana")

        let search = dashboard.openSearch()
        search.search(for: "chicken, rice and broccoli")
        search.result(0).assertExists()
        capture("3-search")
        search.openResult(0).addToDiary()
        search.addedBanner.assertExists()
        search.close()

        dashboard.caloriesConsumed.assertLabel("325")
        capture("2-dashboard")

        let diary = DiaryScreen(app: app)
        diary.show()
        diary.totalCalories.assertLabel("325 kcal")
        capture("4-diary")
    }
}
