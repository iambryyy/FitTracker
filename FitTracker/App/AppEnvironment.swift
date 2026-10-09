//
//  AppEnvironment.swift
//  FitTracker
//

import Foundation
import SwiftUI

/// What the process was asked to do at launch, parsed once from arguments and
/// environment so the rest of the app never touches `ProcessInfo`.
struct LaunchConfiguration: Equatable {
    var isUITesting = false
    var resetState = false
    var seedProfile = false
    var searchMode: SearchMode?

    init() {}

    init(arguments: [String], environment: [String: String]) {
        isUITesting = arguments.contains(LaunchArgument.uiTesting)
        resetState = arguments.contains(LaunchArgument.resetState)
        seedProfile = arguments.contains(LaunchArgument.seedProfile)
        searchMode = environment[LaunchEnvironmentKey.searchMode].flatMap(SearchMode.init(rawValue:))
    }

    static var current: LaunchConfiguration {
        LaunchConfiguration(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }
}

/// Where food search results come from in this run.
enum SearchSource: Equatable {
    case live
    case offlineSamples
    case alwaysFailing
}

/// The app's composition root: builds every long-lived dependency in one place.
@MainActor
struct AppEnvironment {
    static let uiTestDefaultsSuite = "FitTracker.UITests"
    static let apiKeyInfoPlistKey = "CalorieNinjasAPIKey"

    let profileStore: ProfileStore
    let diaryStore: DiaryStore
    let nutritionService: NutritionService
    let searchSource: SearchSource

    static func make(configuration: LaunchConfiguration, bundle: Bundle = .main) -> AppEnvironment {
        let storage = makeStorage(configuration: configuration)
        let profileStore = ProfileStore(storage: storage)
        let diaryStore = DiaryStore(storage: storage)

        if configuration.seedProfile, profileStore.profile == nil {
            profileStore.save(.sample())
        }

        let apiKey = usableAPIKey(bundle.object(forInfoDictionaryKey: apiKeyInfoPlistKey) as? String)
        let source = searchSource(configuration: configuration, apiKey: apiKey)
        return AppEnvironment(
            profileStore: profileStore,
            diaryStore: diaryStore,
            nutritionService: makeService(source: source, apiKey: apiKey, bundle: bundle),
            searchSource: source
        )
    }

    /// UI tests always get the offline database unless they ask for failures;
    /// otherwise the live API is used whenever a key is configured.
    static func searchSource(configuration: LaunchConfiguration, apiKey: String?) -> SearchSource {
        if configuration.isUITesting {
            return configuration.searchMode == .failure ? .alwaysFailing : .offlineSamples
        }
        return usableAPIKey(apiKey) == nil ? .offlineSamples : .live
    }

    /// Trims the key and rejects blanks and unexpanded build-setting placeholders.
    static func usableAPIKey(_ raw: String?) -> String? {
        guard let key = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }

    private static func makeStorage(configuration: LaunchConfiguration) -> KeyValueStoring {
        guard configuration.isUITesting, let defaults = UserDefaults(suiteName: uiTestDefaultsSuite) else {
            return UserDefaults.standard
        }
        if configuration.resetState {
            defaults.removePersistentDomain(forName: uiTestDefaultsSuite)
        }
        return defaults
    }

    private static func makeService(source: SearchSource, apiKey: String?, bundle: Bundle) -> NutritionService {
        switch source {
        case .alwaysFailing:
            return FailingNutritionService()
        case .live:
            return CalorieNinjasService(apiKey: apiKey ?? "")
        case .offlineSamples:
            return (try? OfflineNutritionService(bundle: bundle)) ?? OfflineNutritionService(foods: [])
        }
    }
}

extension UserProfile {
    /// A fixed profile used by `-seed-profile` and by SwiftUI previews.
    static func sample(now: Date = Date(), calendar: Calendar = .current) -> UserProfile {
        UserProfile(
            name: "Alex",
            sex: .male,
            birthDate: calendar.date(byAdding: .year, value: -30, to: now) ?? now,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderate,
            goal: .maintain,
            unitSystem: .metric
        )
    }
}

// MARK: SwiftUI environment

private struct NutritionServiceKey: EnvironmentKey {
    static let defaultValue: NutritionService = OfflineNutritionService(foods: [])
}

private struct SearchSourceKey: EnvironmentKey {
    static let defaultValue: SearchSource = .offlineSamples
}

extension EnvironmentValues {
    var nutritionService: NutritionService {
        get { self[NutritionServiceKey.self] }
        set { self[NutritionServiceKey.self] = newValue }
    }

    var searchSource: SearchSource {
        get { self[SearchSourceKey.self] }
        set { self[SearchSourceKey.self] = newValue }
    }
}
