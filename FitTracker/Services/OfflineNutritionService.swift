//
//  OfflineNutritionService.swift
//  FitTracker
//

import Foundation

/// Food search over a small bundled database. Used when no API key is
/// configured, and by UI tests, which need results that never change.
///
/// Every item is per 100 g. Quantities in the query ("2 eggs") are ignored.
struct OfflineNutritionService: NutritionService {
    static let resourceName = "SampleFoods"

    let foods: [FoodItem]

    init(foods: [FoodItem]) {
        self.foods = foods
    }

    /// Loads `SampleFoods.json` from the given bundle.
    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: Self.resourceName, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        foods = try JSONDecoder().decode(FoodSearchResponse.self, from: data).items
    }

    func search(_ query: String) async throws -> [FoodItem] {
        let terms = Self.terms(in: query)
        guard !terms.isEmpty else { throw NutritionServiceError.emptyQuery }

        var matches: [FoodItem] = []
        for term in terms {
            for food in foods where Self.matches(term: term, foodName: food.name) && !matches.contains(food) {
                matches.append(food)
            }
        }
        return matches
    }

    /// Splits "2 eggs, toast and a banana" into `["egg", "toast", "banana"]`.
    static func terms(in query: String) -> [String] {
        query
            .lowercased()
            .replacingOccurrences(of: " and ", with: ",")
            .split(separator: ",")
            .map { part in
                part.split(separator: " ")
                    .filter { word in !fillerWords.contains(String(word)) && Double(word) == nil }
                    .map { singular(String($0)) }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
    }

    private static let fillerWords: Set<String> = ["a", "an", "the", "of", "some", "cup", "cups", "slice", "slices", "g", "oz"]

    /// Naive English singular: enough to make "eggs", "tomatoes" and
    /// "strawberries" line up with "egg", "tomato" and "strawberry".
    static func singular(_ word: String) -> String {
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 { return String(word.dropLast()) }
        return word
    }

    /// Both sides are compared in singular form, so plurals match either way.
    private static func matches(term: String, foodName: String) -> Bool {
        let name = foodName.lowercased().split(separator: " ").map { singular(String($0)) }.joined(separator: " ")
        return name.contains(term) || term.contains(name)
    }
}

/// A service whose every search fails. Lets UI tests exercise the error state
/// without depending on real network conditions.
struct FailingNutritionService: NutritionService {
    var error: NutritionServiceError = .network(.notConnectedToInternet)

    func search(_ query: String) async throws -> [FoodItem] {
        throw error
    }
}
