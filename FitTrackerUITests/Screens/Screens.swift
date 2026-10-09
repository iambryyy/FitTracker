//
//  Screens.swift
//  FitTrackerUITests
//
//  Page objects: one type per screen. Tests describe what the user does;
//  these types know how to find the controls.
//

import XCTest

struct ProfileFormScreen {
    let app: XCUIApplication

    var nameField: XCUIElement { app.textFields[AccessibilityID.ProfileForm.nameField] }
    var heightCmField: XCUIElement { app.textFields[AccessibilityID.ProfileForm.heightCmField] }
    var heightFeetField: XCUIElement { app.textFields[AccessibilityID.ProfileForm.heightFeetField] }
    var heightInchesField: XCUIElement { app.textFields[AccessibilityID.ProfileForm.heightInchesField] }
    var weightField: XCUIElement { app.textFields[AccessibilityID.ProfileForm.weightField] }
    var errors: XCUIElement { app.element(AccessibilityID.ProfileForm.errors) }
    var goalPreview: XCUIElement { app.staticTexts[AccessibilityID.ProfileForm.goalPreview] }

    func selectUnits(_ title: String) {
        app.segmentedControls[AccessibilityID.ProfileForm.unitPicker].buttons[title].tap()
    }

    var keyboardDoneButton: XCUIElement { app.buttons[AccessibilityID.ProfileForm.keyboardDoneButton] }

    /// Types into a field, then closes the keyboard so it cannot cover the next one.
    func type(_ text: String, into field: XCUIElement) {
        field.assertExists()
        field.tap()
        field.typeText(text)
        dismissKeyboard()
    }

    func replace(_ field: XCUIElement, with text: String) {
        field.assertExists()
        field.replaceText(with: text)
        dismissKeyboard()
    }

    func dismissKeyboard() {
        keyboardDoneButton.assertExists().tap()
        app.keyboards.firstMatch.assertGone()
    }

    /// Fills the form in metric units.
    func fillMetric(name: String, heightCm: String, weightKg: String) {
        selectUnits("Metric")
        type(name, into: nameField)
        type(heightCm, into: heightCmField)
        type(weightKg, into: weightField)
    }
}

struct OnboardingScreen {
    let app: XCUIApplication

    var title: XCUIElement { app.staticTexts[AccessibilityID.Onboarding.title] }
    var submitButton: XCUIElement { app.buttons[AccessibilityID.Onboarding.submitButton] }
    var form: ProfileFormScreen { ProfileFormScreen(app: app) }
}

struct DashboardScreen {
    let app: XCUIApplication

    var greeting: XCUIElement { app.staticTexts[AccessibilityID.Dashboard.greeting] }
    var caloriesConsumed: XCUIElement { app.staticTexts[AccessibilityID.Dashboard.caloriesConsumed] }
    var calorieGoal: XCUIElement { app.staticTexts[AccessibilityID.Dashboard.calorieGoal] }
    var caloriesRemaining: XCUIElement { app.staticTexts[AccessibilityID.Dashboard.caloriesRemaining] }
    var emptyLogMessage: XCUIElement { app.staticTexts[AccessibilityID.Dashboard.emptyLog] }
    var logFoodButton: XCUIElement { app.buttons[AccessibilityID.Dashboard.logFoodButton] }

    func show() {
        app.tabBars.buttons["Today"].tap()
        greeting.assertExists()
    }

    func openSearch() -> SearchScreen {
        logFoodButton.assertExists().tap()
        let search = SearchScreen(app: app)
        search.field.assertExists()
        return search
    }

    /// Logs one serving of the first search result for `query` and returns to the dashboard.
    func logFood(_ query: String) {
        let search = openSearch()
        search.search(for: query)
        search.openResult(0).addToDiary()
        search.addedBanner.assertExists()
        search.close()
    }
}

struct SearchScreen {
    let app: XCUIApplication

    var field: XCUIElement { app.textFields[AccessibilityID.Search.field] }
    var submitButton: XCUIElement { app.buttons[AccessibilityID.Search.submitButton] }
    var doneButton: XCUIElement { app.buttons[AccessibilityID.Search.doneButton] }
    var emptyState: XCUIElement { app.element(AccessibilityID.Search.emptyState) }
    var errorMessage: XCUIElement { app.element(AccessibilityID.Search.errorState) }
    var retryButton: XCUIElement { app.buttons[AccessibilityID.Search.retryButton] }
    var addedBanner: XCUIElement { app.element(AccessibilityID.Search.addedBanner) }
    var sourceNote: XCUIElement { app.element(AccessibilityID.Search.sourceNote) }

    func result(_ index: Int) -> XCUIElement {
        app.element(AccessibilityID.Search.result(index))
    }

    func search(for query: String) {
        field.tap()
        field.typeText(query)
        submitButton.tap()
    }

    func openResult(_ index: Int) -> FoodDetailScreen {
        result(index).assertExists().tap()
        let detail = FoodDetailScreen(app: app)
        detail.addButton.assertExists()
        return detail
    }

    func close() {
        doneButton.tap()
        field.assertGone()
    }
}

struct FoodDetailScreen {
    let app: XCUIApplication

    var calories: XCUIElement { app.staticTexts[AccessibilityID.FoodDetail.calories] }
    var addButton: XCUIElement { app.buttons[AccessibilityID.FoodDetail.addButton] }
    var incrementServings: XCUIElement {
        // SwiftUI derives the stepper's button identifiers from the stepper's own.
        app.buttons["\(AccessibilityID.FoodDetail.servingsStepper)-Increment"]
    }

    func addToDiary() {
        addButton.tap()
    }
}

struct DiaryScreen {
    let app: XCUIApplication

    var totalCalories: XCUIElement { app.staticTexts[AccessibilityID.Diary.totalCalories] }
    var dateLabel: XCUIElement { app.staticTexts[AccessibilityID.Diary.dateLabel] }
    var emptyState: XCUIElement { app.element(AccessibilityID.Diary.emptyState) }
    var previousDayButton: XCUIElement { app.buttons[AccessibilityID.Diary.previousDayButton] }
    var nextDayButton: XCUIElement { app.buttons[AccessibilityID.Diary.nextDayButton] }

    func show() {
        app.tabBars.buttons["Diary"].tap()
        totalCalories.assertExists()
    }

    func rows(named name: String) -> XCUIElementQuery {
        app.collectionViews.staticTexts.matching(NSPredicate(format: "label == %@", name))
    }

    func deleteFirstRow(named name: String) {
        let row = rows(named: name).firstMatch
        row.assertExists()
        row.swipeLeft()
        app.buttons["Delete"].assertExists().tap()
    }
}

struct ProfileScreen {
    let app: XCUIApplication

    var form: ProfileFormScreen { ProfileFormScreen(app: app) }
    var saveButton: XCUIElement { app.buttons[AccessibilityID.Profile.saveButton] }
    var savedConfirmation: XCUIElement { app.element(AccessibilityID.Profile.savedConfirmation) }
    var resetButton: XCUIElement { app.buttons[AccessibilityID.Profile.resetButton] }
    var confirmResetButton: XCUIElement { app.buttons[AccessibilityID.Profile.confirmResetButton] }

    func show() {
        app.tabBars.buttons["Profile"].tap()
        saveButton.assertExists()
    }
}
