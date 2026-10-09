//
//  UserProfile.swift
//  FitTracker
//

import Foundation

enum BiologicalSex: String, Codable, CaseIterable, Identifiable, Sendable {
    case female, male

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary, light, moderate, veryActive, extraActive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .veryActive: return "Very active"
        case .extraActive: return "Extra active"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .light: return "Exercise 1–3 days a week"
        case .moderate: return "Exercise 3–5 days a week"
        case .veryActive: return "Exercise 6–7 days a week"
        case .extraActive: return "Physical job or twice-daily training"
        }
    }

    /// Standard activity multiplier applied to basal metabolic rate.
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case lose, maintain, gain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lose: return "Lose"
        case .maintain: return "Maintain"
        case .gain: return "Gain"
        }
    }

    /// Daily calorie adjustment relative to maintenance.
    var calorieAdjustment: Double {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return 300
        }
    }

    /// Daily protein target in grams per kilogram of body weight.
    var proteinGramsPerKg: Double {
        switch self {
        case .lose: return 2.0
        case .maintain: return 1.6
        case .gain: return 1.8
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case imperial, metric

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Everything FitTracker knows about the person using it. Height and weight are
/// always stored in metric; `unitSystem` only controls how they are shown.
struct UserProfile: Codable, Equatable, Sendable {
    var name: String
    var sex: BiologicalSex
    var birthDate: Date
    var heightCm: Double
    var weightKg: Double
    var activityLevel: ActivityLevel
    var goal: FitnessGoal
    var unitSystem: UnitSystem

    /// Age in whole years on the given date.
    func age(on date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: date).year ?? 0
    }
}
