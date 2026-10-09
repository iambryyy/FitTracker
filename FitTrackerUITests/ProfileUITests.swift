//
//  ProfileUITests.swift
//  FitTrackerUITests
//

import XCTest

final class ProfileUITests: FitTrackerUITestCase {

    private var dashboard: DashboardScreen { DashboardScreen(app: app) }
    private var profile: ProfileScreen { ProfileScreen(app: app) }

    private func goalValue() throws -> Int {
        let label = dashboard.calorieGoal.assertExists().label
        return try XCTUnwrap(Int(label.replacingOccurrences(of: ",", with: "")), "Unexpected goal label: \(label)")
    }

    func testProfileTabShowsTheSavedProfile() {
        launch()
        profile.show()

        // The seeded profile is Alex, 180 cm, 80 kg, metric.
        XCTAssertEqual(profile.form.nameField.value as? String, "Alex")
        XCTAssertEqual(profile.form.heightCmField.value as? String, "180")
        XCTAssertEqual(profile.form.weightField.value as? String, "80")
    }

    func testIncreasingWeightRaisesTheCalorieGoal() throws {
        launch()
        let originalGoal = try goalValue()

        profile.show()
        profile.form.replace(profile.form.weightField, with: "90")
        profile.saveButton.tap()
        profile.savedConfirmation.assertExists()

        dashboard.show()
        // 10 kg more adds 100 kcal of BMR, times the 1.55 activity multiplier.
        XCTAssertEqual(try goalValue(), originalGoal + 155)
    }

    func testInvalidEditIsRejectedAndNotSaved() throws {
        launch()
        let originalGoal = try goalValue()

        profile.show()
        profile.form.replace(profile.form.weightField, with: "5")
        profile.saveButton.tap()

        let errors = profile.form.errors.assertExists().label
        XCTAssertTrue(errors.contains("Weight must be between"), errors)
        XCTAssertFalse(profile.savedConfirmation.exists)

        dashboard.show()
        XCTAssertEqual(try goalValue(), originalGoal)
    }

    func testResetAllDataReturnsToOnboardingAndClearsTheDiary() {
        launch()
        dashboard.logFood("banana")

        profile.show()
        profile.resetButton.tap()
        profile.confirmResetButton.assertExists().tap()

        let onboarding = OnboardingScreen(app: app)
        onboarding.title.assertExists()

        // Relaunch without reseeding: nothing may have survived the reset.
        app.terminate()
        launch(reset: false, seedProfile: false)
        onboarding.title.assertExists()

        onboarding.form.fillMetric(name: "Sam", heightCm: "175", weightKg: "70")
        onboarding.submitButton.tap()
        dashboard.caloriesConsumed.assertLabel("0")
    }
}
