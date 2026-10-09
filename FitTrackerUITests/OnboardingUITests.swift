//
//  OnboardingUITests.swift
//  FitTrackerUITests
//

import XCTest

final class OnboardingUITests: FitTrackerUITestCase {

    private var onboarding: OnboardingScreen { OnboardingScreen(app: app) }
    private var dashboard: DashboardScreen { DashboardScreen(app: app) }

    func testFirstLaunchShowsOnboarding() {
        launch(seedProfile: false)

        onboarding.title.assertExists()
        XCTAssertFalse(app.tabBars.firstMatch.exists, "Tabs must not be reachable before a profile exists")
    }

    func testCompletingOnboardingShowsDashboardWithTheSameGoalThatWasPreviewed() throws {
        launch(seedProfile: false)
        onboarding.form.fillMetric(name: "Sam", heightCm: "175", weightKg: "70")

        // The form previews the goal as "Daily goal: 2,345 kcal".
        let preview = onboarding.form.goalPreview.assertExists().label
        let previewedGoal = try XCTUnwrap(preview.split(separator: " ").dropFirst(2).first.map(String.init))

        onboarding.submitButton.tap()

        dashboard.greeting.assertLabel("Hi, Sam")
        dashboard.calorieGoal.assertLabel(previewedGoal)
        dashboard.caloriesConsumed.assertLabel("0")
        dashboard.caloriesRemaining.assertLabel(previewedGoal)
    }

    func testSubmittingAnEmptyFormListsEveryProblemAndStaysOnOnboarding() {
        launch(seedProfile: false)

        onboarding.submitButton.assertExists().tap()

        let errors = onboarding.form.errors.assertExists().label
        XCTAssertTrue(errors.contains("Enter your name."), errors)
        XCTAssertTrue(errors.contains("Enter your height as a number."), errors)
        XCTAssertTrue(errors.contains("Enter your weight as a number."), errors)
        onboarding.title.assertExists()
    }

    func testErrorsClearAsSoonAsTheFormIsEdited() {
        launch(seedProfile: false)
        onboarding.submitButton.assertExists().tap()
        onboarding.form.errors.assertExists()

        onboarding.form.type("Sam", into: onboarding.form.nameField)

        onboarding.form.errors.assertGone()
    }

    func testOutOfRangeHeightIsRejected() {
        launch(seedProfile: false)
        onboarding.form.fillMetric(name: "Sam", heightCm: "20", weightKg: "70")

        XCTAssertFalse(onboarding.form.goalPreview.exists, "No goal should be previewed for invalid input")
        onboarding.submitButton.tap()

        let errors = onboarding.form.errors.assertExists().label
        XCTAssertTrue(errors.contains("Height must be between"), errors)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    func testSwitchingUnitsConvertsTypedValues() {
        launch(seedProfile: false)
        let form = onboarding.form
        form.type("5", into: form.heightFeetField)
        form.type("11", into: form.heightInchesField)
        form.type("170", into: form.weightField)

        form.selectUnits("Metric")

        XCTAssertEqual(form.heightCmField.assertExists().value as? String, "180.3")
        XCTAssertEqual(form.weightField.value as? String, "77.1")

        form.selectUnits("Imperial")

        XCTAssertEqual(form.heightFeetField.assertExists().value as? String, "5")
        XCTAssertEqual(form.heightInchesField.value as? String, "11")
    }

    func testCompletedOnboardingIsRememberedOnNextLaunch() {
        launch(seedProfile: false)
        onboarding.form.fillMetric(name: "Sam", heightCm: "175", weightKg: "70")
        onboarding.submitButton.tap()
        dashboard.greeting.assertExists()

        app.terminate()
        launch(reset: false, seedProfile: false)

        dashboard.greeting.assertLabel("Hi, Sam")
    }
}
