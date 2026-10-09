//
//  FoodLoggingUITests.swift
//  FitTrackerUITests
//
//  All expected numbers come from FitTracker/Resources/SampleFoods.json:
//  banana is 89 kcal and chicken breast is 165 kcal per serving.
//

import XCTest

final class FoodLoggingUITests: FitTrackerUITestCase {

    private var dashboard: DashboardScreen { DashboardScreen(app: app) }
    private var diary: DiaryScreen { DiaryScreen(app: app) }

    func testDashboardStartsWithNothingLogged() {
        launch()

        dashboard.caloriesConsumed.assertLabel("0")
        dashboard.emptyLogMessage.assertExists()
    }

    func testLoggingFoodUpdatesDashboardAndDiary() throws {
        launch()
        let goal = try XCTUnwrap(Int(dashboard.calorieGoal.assertExists().label.replacingOccurrences(of: ",", with: "")))

        dashboard.logFood("banana")

        dashboard.caloriesConsumed.assertLabel("89")
        dashboard.caloriesRemaining.assertLabel((goal - 89).formatted())
        dashboard.emptyLogMessage.assertGone()

        diary.show()
        diary.totalCalories.assertLabel("89 kcal")
        XCTAssertEqual(diary.rows(named: "Banana").count, 1)
    }

    func testCompoundQueryReturnsEachFood() {
        launch()
        let search = dashboard.openSearch()

        search.search(for: "2 eggs and toast")

        XCTAssertTrue(search.result(0).assertExists().label.contains("Egg"))
        XCTAssertTrue(search.result(1).assertExists().label.contains("Toast"))
        XCTAssertFalse(search.result(2).exists)
    }

    func testServingsStepperScalesCaloriesBeforeAndAfterAdding() {
        launch()
        let search = dashboard.openSearch()
        search.search(for: "banana")
        let detail = search.openResult(0)
        // The row is one accessibility element, read as "Calories, 89 kcal".
        detail.calories.assertLabel("Calories, 89 kcal")

        detail.incrementServings.tap()
        detail.incrementServings.tap()

        detail.calories.assertLabel("Calories, 178 kcal")
        detail.addToDiary()
        search.close()
        dashboard.caloriesConsumed.assertLabel("178")
    }

    func testSameFoodCanBeLoggedTwiceAndRemovedIndependently() {
        // Regression: the original app identified diary rows by food name, so
        // duplicates shared an identity and could not be removed one at a time.
        launch()
        dashboard.logFood("banana")
        dashboard.logFood("banana")
        dashboard.caloriesConsumed.assertLabel("178")

        diary.show()
        XCTAssertEqual(diary.rows(named: "Banana").count, 2)
        diary.deleteFirstRow(named: "Banana")

        diary.totalCalories.assertLabel("89 kcal")
        XCTAssertEqual(diary.rows(named: "Banana").count, 1)
        dashboard.show()
        dashboard.caloriesConsumed.assertLabel("89")
    }

    func testDeletingTheLastEntryShowsTheEmptyState() {
        launch()
        dashboard.logFood("chicken")
        diary.show()
        diary.totalCalories.assertLabel("165 kcal")

        diary.deleteFirstRow(named: "Chicken Breast")

        diary.emptyState.assertExists()
        diary.totalCalories.assertLabel("0 kcal")
    }

    func testDiaryDaysAreSeparate() {
        launch()
        dashboard.logFood("banana")
        diary.show()
        diary.dateLabel.assertLabel("Today")
        XCTAssertFalse(diary.nextDayButton.isEnabled, "The diary must not navigate into the future")

        diary.previousDayButton.tap()

        diary.emptyState.assertExists()
        diary.totalCalories.assertLabel("0 kcal")

        diary.nextDayButton.tap()

        diary.dateLabel.assertLabel("Today")
        diary.totalCalories.assertLabel("89 kcal")
    }

    func testLoggedFoodPersistsAcrossRelaunch() {
        // Regression: the original dashboard showed 0 calories after a relaunch
        // until the diary screen had been opened.
        launch()
        dashboard.logFood("banana")
        dashboard.caloriesConsumed.assertLabel("89")

        app.terminate()
        launch(reset: false)

        dashboard.caloriesConsumed.assertLabel("89")
    }

    func testSearchWithNoMatchesShowsEmptyState() {
        launch()
        let search = dashboard.openSearch()

        search.search(for: "dragonfruit")

        search.emptyState.assertExists()
        XCTAssertFalse(search.result(0).exists)
    }

    func testSearchButtonIsDisabledForBlankQuery() {
        launch()
        let search = dashboard.openSearch()

        XCTAssertFalse(search.submitButton.isEnabled)
        search.field.tap()
        search.field.typeText("   ")
        XCTAssertFalse(search.submitButton.isEnabled)
        search.field.typeText("egg")
        XCTAssertTrue(search.submitButton.isEnabled)
    }

    func testSearchFailureShowsMessageAndOffersRetry() {
        launch(searchMode: .failure)
        let search = dashboard.openSearch()

        search.search(for: "banana")

        XCTAssertTrue(search.errorMessage.assertExists().label.contains("offline"))
        search.retryButton.assertExists().tap()
        search.errorMessage.assertExists()

        search.close()
        dashboard.caloriesConsumed.assertLabel("0")
    }
}
