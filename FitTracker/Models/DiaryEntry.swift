//
//  DiaryEntry.swift
//  FitTracker
//

import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// The meal a user is most likely logging at the given time of day.
    static func suggested(for date: Date, calendar: Calendar = .current) -> MealType {
        switch calendar.component(.hour, from: date) {
        case 4..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}

/// One logged food. Each entry has its own identity, so the same food can be
/// logged any number of times and removed individually.
struct DiaryEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var food: FoodItem
    /// Multiplier applied to the food's nutrition facts.
    var servings: Double
    var meal: MealType
    var loggedAt: Date

    init(id: UUID = UUID(), food: FoodItem, servings: Double = 1, meal: MealType, loggedAt: Date) {
        self.id = id
        self.food = food
        self.servings = servings
        self.meal = meal
        self.loggedAt = loggedAt
    }

    var calories: Double { food.calories * servings }
    var proteinG: Double { food.proteinG * servings }
    var carbohydratesG: Double { food.carbohydratesTotalG * servings }
    var fatG: Double { food.fatTotalG * servings }
}

/// Summed nutrition for a set of diary entries.
struct NutritionTotals: Equatable, Sendable {
    var calories: Double = 0
    var proteinG: Double = 0
    var carbohydratesG: Double = 0
    var fatG: Double = 0

    static let zero = NutritionTotals()

    init(calories: Double = 0, proteinG: Double = 0, carbohydratesG: Double = 0, fatG: Double = 0) {
        self.calories = calories
        self.proteinG = proteinG
        self.carbohydratesG = carbohydratesG
        self.fatG = fatG
    }

    init(_ entries: some Sequence<DiaryEntry>) {
        for entry in entries {
            calories += entry.calories
            proteinG += entry.proteinG
            carbohydratesG += entry.carbohydratesG
            fatG += entry.fatG
        }
    }
}
