//
//  UITestSupport.swift
//  Shared between the FitTracker app and the FitTrackerUITests target.
//
//  Keeping launch flags and accessibility identifiers in one file means the
//  app and its UI tests can never drift apart on a string literal.
//

import Foundation

/// Command-line flags the app understands at launch.
enum LaunchArgument {
    /// Use an isolated defaults suite, the offline food database, and no animations.
    static let uiTesting = "-ui-testing"
    /// Wipe the isolated defaults suite before the app reads it.
    static let resetState = "-reset-state"
    /// Skip onboarding by saving a known sample profile.
    static let seedProfile = "-seed-profile"
}

enum LaunchEnvironmentKey {
    /// Selects the food search backend under UI test. See `SearchMode`.
    static let searchMode = "FT_SEARCH_MODE"
}

/// Food search backends that can be forced from a UI test.
enum SearchMode: String {
    /// Bundled sample database. Deterministic, no network.
    case offline
    /// Every search fails with a network error.
    case failure
}

/// Accessibility identifiers used by XCUITest to find elements.
enum AccessibilityID {
    enum ProfileForm {
        static let nameField = "profileForm.name"
        static let unitPicker = "profileForm.units"
        static let heightCmField = "profileForm.heightCm"
        static let heightFeetField = "profileForm.heightFeet"
        static let heightInchesField = "profileForm.heightInches"
        static let weightField = "profileForm.weight"
        static let sexPicker = "profileForm.sex"
        static let birthDatePicker = "profileForm.birthDate"
        static let activityPicker = "profileForm.activity"
        static let goalPicker = "profileForm.goal"
        static let errors = "profileForm.errors"
        static let goalPreview = "profileForm.goalPreview"
        static let keyboardDoneButton = "profileForm.keyboardDone"
    }

    enum Onboarding {
        static let title = "onboarding.title"
        static let submitButton = "onboarding.submit"
    }

    enum Tab {
        static let today = "tab.today"
        static let diary = "tab.diary"
        static let profile = "tab.profile"
    }

    enum Dashboard {
        static let greeting = "dashboard.greeting"
        static let caloriesConsumed = "dashboard.caloriesConsumed"
        static let calorieGoal = "dashboard.calorieGoal"
        static let caloriesRemaining = "dashboard.caloriesRemaining"
        static let calorieRing = "dashboard.calorieRing"
        static let logFoodButton = "dashboard.logFood"
        static let emptyLog = "dashboard.emptyLog"
        static let bmiValue = "dashboard.bmi"
    }

    enum Search {
        static let field = "search.field"
        static let submitButton = "search.submit"
        static let doneButton = "search.done"
        static let loading = "search.loading"
        static let emptyState = "search.empty"
        static let errorState = "search.error"
        static let retryButton = "search.retry"
        static let addedBanner = "search.addedBanner"
        static let sourceNote = "search.sourceNote"
        static func result(_ index: Int) -> String { "search.result.\(index)" }
    }

    enum FoodDetail {
        static let calories = "foodDetail.calories"
        static let servingsStepper = "foodDetail.servings"
        static let mealPicker = "foodDetail.meal"
        static let addButton = "foodDetail.add"
    }

    enum Diary {
        static let dateLabel = "diary.date"
        static let previousDayButton = "diary.previousDay"
        static let nextDayButton = "diary.nextDay"
        static let addButton = "diary.add"
        static let totalCalories = "diary.totalCalories"
        static let emptyState = "diary.empty"
    }

    enum Profile {
        static let saveButton = "profile.save"
        static let savedConfirmation = "profile.saved"
        static let resetButton = "profile.reset"
        static let confirmResetButton = "profile.confirmReset"
    }
}
