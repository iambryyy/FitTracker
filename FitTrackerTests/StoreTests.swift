//
//  StoreTests.swift
//  FitTrackerTests
//

import Foundation
import Testing
@testable import FitTracker

@Suite("DiaryStore")
@MainActor
struct DiaryStoreTests {
    private let storage = InMemoryKeyValueStore()
    private let noon = TestClock.date(2025, 6, 15, hour: 12)

    private func makeStore() -> DiaryStore {
        DiaryStore(storage: storage, calendar: TestClock.calendar)
    }

    // MARK: Adding and totals

    @Test("A new store is empty")
    func startsEmpty() {
        let store = makeStore()
        #expect(store.entries.isEmpty)
        #expect(store.totals(on: noon) == .zero)
        #expect(!store.didFailToLoad)
    }

    @Test("Adding food updates the day's totals")
    func addUpdatesTotals() {
        let store = makeStore()
        store.add(.banana, meal: .breakfast, at: noon)
        store.add(.chicken, meal: .lunch, at: noon)

        let totals = store.totals(on: noon)
        #expect(totals.calories == 254)
        #expect(isClose(totals.proteinG, 32.1))
        #expect(isClose(totals.carbohydratesG, 22.8))
        #expect(isClose(totals.fatG, 3.9))
    }

    @Test("Servings scale every nutrient", arguments: [0.5, 1.0, 2.5])
    func servingsScale(servings: Double) {
        let store = makeStore()
        let entry = store.add(.chicken, servings: servings, meal: .dinner, at: noon)
        #expect(isClose(entry.calories, 165 * servings))
        #expect(isClose(entry.proteinG, 31 * servings))
        #expect(isClose(store.totals(on: noon).calories, 165 * servings))
    }

    @Test("Negative servings are clamped to zero")
    func negativeServings() {
        let store = makeStore()
        let entry = store.add(.banana, servings: -2, meal: .snack, at: noon)
        #expect(entry.servings == 0)
        #expect(store.totals(on: noon).calories == 0)
    }

    // MARK: Removing

    @Test("Logging the same food twice creates two independent entries")
    func duplicateFoods() {
        // The original app keyed diary rows by food name, so duplicates collided.
        let store = makeStore()
        let first = store.add(.banana, meal: .breakfast, at: noon)
        let second = store.add(.banana, meal: .snack, at: noon)
        #expect(first.id != second.id)

        store.remove(id: first.id)

        #expect(store.entries.map(\.id) == [second.id])
        #expect(store.totals(on: noon).calories == 89)
    }

    @Test("Removing an unknown id does nothing")
    func removeUnknown() {
        let store = makeStore()
        store.add(.banana, meal: .breakfast, at: noon)
        store.remove(id: UUID())
        #expect(store.entries.count == 1)
    }

    @Test("removeAll clears every day")
    func removeAll() {
        let store = makeStore()
        store.add(.banana, meal: .breakfast, at: noon)
        store.add(.banana, meal: .breakfast, at: TestClock.date(2025, 6, 1))
        store.removeAll()
        #expect(store.entries.isEmpty)
        #expect(makeStore().entries.isEmpty)
    }

    // MARK: Days and meals

    @Test("Entries are scoped to their calendar day, split exactly at midnight")
    func dayBoundaries() {
        let store = makeStore()
        store.add(.banana, meal: .snack, at: TestClock.date(2025, 6, 14, hour: 23, minute: 59))
        store.add(.chicken, meal: .breakfast, at: TestClock.date(2025, 6, 15, hour: 0, minute: 0))
        store.add(.chicken, meal: .dinner, at: TestClock.date(2025, 6, 15, hour: 23, minute: 59))
        store.add(.banana, meal: .breakfast, at: TestClock.date(2025, 6, 16, hour: 0, minute: 0))

        #expect(store.totals(on: TestClock.date(2025, 6, 14, hour: 8)).calories == 89)
        #expect(store.totals(on: noon).calories == 330)
        #expect(store.totals(on: TestClock.date(2025, 6, 16, hour: 8)).calories == 89)
        #expect(store.totals(on: TestClock.date(2025, 6, 17)).calories == 0)
    }

    @Test("A day's entries come back oldest first regardless of insertion order")
    func sortedByTime() {
        let store = makeStore()
        store.add(.chicken, meal: .dinner, at: TestClock.date(2025, 6, 15, hour: 19))
        store.add(.banana, meal: .breakfast, at: TestClock.date(2025, 6, 15, hour: 7))
        #expect(store.entries(on: noon).map(\.food.name) == ["banana", "chicken breast"])
    }

    @Test("Entries can be filtered by meal")
    func filterByMeal() {
        let store = makeStore()
        store.add(.banana, meal: .breakfast, at: noon)
        store.add(.chicken, meal: .lunch, at: noon)
        #expect(store.entries(on: noon, meal: .lunch).map(\.food.name) == ["chicken breast"])
        #expect(store.entries(on: noon, meal: .dinner).isEmpty)
    }

    // MARK: Persistence

    @Test("Entries survive being reloaded from storage")
    func persistence() {
        let entry = makeStore().add(.banana, servings: 2, meal: .snack, at: noon)

        let reloaded = makeStore()

        #expect(reloaded.entries == [entry])
    }

    @Test("Removals are persisted too")
    func persistsRemoval() {
        let store = makeStore()
        let entry = store.add(.banana, meal: .snack, at: noon)
        store.remove(id: entry.id)
        #expect(makeStore().entries.isEmpty)
    }

    @Test("Corrupt saved data yields an empty diary and is flagged, not a crash")
    func corruptData() {
        storage.setData(Data("not json".utf8), forKey: DiaryStore.storageKey)

        let store = makeStore()

        #expect(store.entries.isEmpty)
        #expect(store.didFailToLoad)
        // The unreadable bytes are not overwritten until the user saves something.
        #expect(storage.data(forKey: DiaryStore.storageKey) == Data("not json".utf8))

        store.add(.banana, meal: .snack, at: noon)
        #expect(!store.didFailToLoad)
        #expect(makeStore().entries.count == 1)
    }
}

@Suite("MealType")
struct MealTypeTests {
    @Test("Suggested meal follows the time of day", arguments: [
        (3, MealType.snack), (4, .breakfast), (10, .breakfast), (11, .lunch), (14, .lunch),
        (15, .snack), (16, .snack), (17, .dinner), (21, .dinner), (22, .snack), (0, .snack)
    ])
    func suggested(hour: Int, expected: MealType) {
        let date = TestClock.date(2025, 6, 15, hour: hour)
        #expect(MealType.suggested(for: date, calendar: TestClock.calendar) == expected)
    }
}

@Suite("ProfileStore")
@MainActor
struct ProfileStoreTests {
    private let storage = InMemoryKeyValueStore()

    @Test("There is no profile before onboarding")
    func startsEmpty() {
        #expect(ProfileStore(storage: storage).profile == nil)
    }

    @Test("A saved profile is restored on the next launch")
    func persistence() {
        ProfileStore(storage: storage).save(.reference)
        #expect(ProfileStore(storage: storage).profile == .reference)
    }

    @Test("Saving again replaces the previous profile")
    func overwrite() {
        let store = ProfileStore(storage: storage)
        store.save(.reference)
        var updated = UserProfile.reference
        updated.weightKg = 75
        store.save(updated)
        #expect(ProfileStore(storage: storage).profile?.weightKg == 75)
    }

    @Test("Clearing removes the profile from memory and storage")
    func clear() {
        let store = ProfileStore(storage: storage)
        store.save(.reference)
        store.clear()
        #expect(store.profile == nil)
        #expect(storage.data(forKey: ProfileStore.storageKey) == nil)
    }

    @Test("Corrupt saved data is treated as no profile")
    func corruptData() {
        storage.setData(Data("{".utf8), forKey: ProfileStore.storageKey)
        #expect(ProfileStore(storage: storage).profile == nil)
    }
}

@Suite("FoodSearchModel")
@MainActor
struct FoodSearchModelTests {

    @Test("Starts idle")
    func startsIdle() {
        #expect(FoodSearchModel(service: MockNutritionService()).state == .idle)
    }

    @Test("A blank query stays idle and never reaches the service", arguments: ["", "   ", "\n"])
    func blankQuery(query: String) async {
        let service = MockNutritionService(result: .success([.banana]))
        let model = FoodSearchModel(service: service)
        model.query = query
        await model.search()
        #expect(model.state == .idle)
        #expect(service.queries.isEmpty)
    }

    @Test("Results are loaded and the query is trimmed before it is sent")
    func loadsResults() async {
        let service = MockNutritionService(result: .success([.banana, .chicken]))
        let model = FoodSearchModel(service: service)
        model.query = "  banana and chicken "
        await model.search()
        #expect(model.state == .loaded([.banana, .chicken]))
        #expect(service.queries == ["banana and chicken"])
    }

    @Test("No matches shows the empty state with the query that was searched")
    func emptyResults() async {
        let model = FoodSearchModel(service: MockNutritionService(result: .success([])))
        model.query = "dragonfruit"
        await model.search()
        #expect(model.state == .empty(query: "dragonfruit"))
    }

    @Test("A service error shows its user-facing message")
    func failure() async {
        let error = NutritionServiceError.network(.notConnectedToInternet)
        let model = FoodSearchModel(service: MockNutritionService(result: .failure(error)))
        model.query = "apple"
        await model.search()
        #expect(model.state == .failed(message: error.errorDescription ?? ""))
    }

    @Test("An unknown error falls back to a generic message")
    func unknownFailure() async {
        struct Boom: Error {}
        let model = FoodSearchModel(service: MockNutritionService(result: .failure(Boom())))
        model.query = "apple"
        await model.search()
        #expect(model.state == .failed(message: "Something went wrong. Try again."))
    }

    @Test("A cancelled search returns to idle instead of showing an error")
    func cancellation() async {
        let model = FoodSearchModel(service: MockNutritionService(result: .failure(CancellationError())))
        model.query = "apple"
        await model.search()
        #expect(model.state == .idle)
    }

    @Test("Searching again after a failure recovers")
    func retry() async {
        let service = MockNutritionService(result: .failure(NutritionServiceError.rateLimited))
        let model = FoodSearchModel(service: service)
        model.query = "banana"
        await model.search()
        service.result = .success([.banana])
        await model.search()
        #expect(model.state == .loaded([.banana]))
    }

    @Test("A slow response to an older search cannot overwrite newer results")
    func staleResponseIsDropped() async {
        let service = ControlledNutritionService()
        let model = FoodSearchModel(service: service)

        model.query = "banana"
        let first = Task { await model.search() }
        await service.waitForSearches(1)
        #expect(model.state == .loading)

        model.query = "chicken"
        let second = Task { await model.search() }
        await service.waitForSearches(2)

        // The newer search finishes first; the older one arrives late.
        await service.finish(search: 1, with: [.chicken])
        await second.value
        await service.finish(search: 0, with: [.banana])
        await first.value

        #expect(model.state == .loaded([.chicken]))
    }
}

@Suite("App configuration")
@MainActor
struct AppConfigurationTests {

    @Test("No arguments means a normal launch")
    func defaultLaunch() {
        let configuration = LaunchConfiguration(arguments: ["/path/to/FitTracker"], environment: [:])
        #expect(configuration == LaunchConfiguration())
    }

    @Test("Launch arguments and environment are parsed")
    func parsesFlags() {
        let configuration = LaunchConfiguration(
            arguments: ["app", LaunchArgument.uiTesting, LaunchArgument.resetState, LaunchArgument.seedProfile],
            environment: [LaunchEnvironmentKey.searchMode: "failure"]
        )
        #expect(configuration.isUITesting)
        #expect(configuration.resetState)
        #expect(configuration.seedProfile)
        #expect(configuration.searchMode == .failure)
    }

    @Test("An unrecognised search mode is ignored")
    func unknownSearchMode() {
        let configuration = LaunchConfiguration(arguments: [], environment: [LaunchEnvironmentKey.searchMode: "bogus"])
        #expect(configuration.searchMode == nil)
    }

    @Test("API keys are trimmed; blanks and unexpanded placeholders are rejected", arguments: [
        (nil, nil),
        ("", nil),
        ("   ", nil),
        ("$(CALORIE_NINJAS_API_KEY)", nil),
        ("  abc123==  ", "abc123==")
    ] as [(String?, String?)])
    func usableAPIKey(raw: String?, expected: String?) {
        #expect(AppEnvironment.usableAPIKey(raw) == expected)
    }

    @Test("Search uses the live API only when a key is present outside UI tests")
    @MainActor
    func searchSourceSelection() {
        var uiTest = LaunchConfiguration()
        uiTest.isUITesting = true
        var failingUITest = uiTest
        failingUITest.searchMode = .failure

        #expect(AppEnvironment.searchSource(configuration: LaunchConfiguration(), apiKey: "key") == .live)
        #expect(AppEnvironment.searchSource(configuration: LaunchConfiguration(), apiKey: nil) == .offlineSamples)
        #expect(AppEnvironment.searchSource(configuration: LaunchConfiguration(), apiKey: " ") == .offlineSamples)
        // UI tests must never hit the network, even if a key is configured.
        #expect(AppEnvironment.searchSource(configuration: uiTest, apiKey: "key") == .offlineSamples)
        #expect(AppEnvironment.searchSource(configuration: failingUITest, apiKey: "key") == .alwaysFailing)
    }

    @Test("A UI-test launch with reset and seed starts from a known state")
    @MainActor
    func uiTestEnvironment() {
        var configuration = LaunchConfiguration()
        configuration.isUITesting = true
        configuration.resetState = true
        configuration.seedProfile = true

        let environment = AppEnvironment.make(configuration: configuration)

        #expect(environment.profileStore.profile?.name == "Alex")
        #expect(environment.diaryStore.entries.isEmpty)
        #expect(environment.searchSource == .offlineSamples)
    }
}
