//
//  NutritionCalculator.swift
//  FitTracker
//

import Foundation

enum BMICategory: String, Equatable, Sendable {
    case underweight, healthy, overweight, obese

    var title: String {
        switch self {
        case .underweight: return "Underweight"
        case .healthy: return "Healthy weight"
        case .overweight: return "Overweight"
        case .obese: return "Obese"
        }
    }

    /// WHO adult cut-offs. Each lower bound is inclusive.
    init(bmi: Double) {
        switch bmi {
        case ..<18.5: self = .underweight
        case ..<25: self = .healthy
        case ..<30: self = .overweight
        default: self = .obese
        }
    }
}

struct MacroTargets: Equatable, Sendable {
    var proteinG: Double
    var carbohydratesG: Double
    var fatG: Double
}

/// Pure functions that turn a profile into daily targets. No state, no I/O.
enum NutritionCalculator {
    /// Calorie goals are never set below this, however aggressive the deficit.
    static let minimumDailyCalories = 1200.0
    /// Share of daily calories assigned to fat.
    static let fatCalorieShare = 0.25

    static let caloriesPerGramProtein = 4.0
    static let caloriesPerGramCarbohydrate = 4.0
    static let caloriesPerGramFat = 9.0

    /// Body mass index, or `nil` when height or weight is not positive.
    static func bmi(weightKg: Double, heightCm: Double) -> Double? {
        guard weightKg > 0, heightCm > 0 else { return nil }
        let heightM = heightCm / 100
        return weightKg / (heightM * heightM)
    }

    /// Basal metabolic rate in kcal/day using the Mifflin-St Jeor equation.
    static func bmr(weightKg: Double, heightCm: Double, ageYears: Int, sex: BiologicalSex) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// Total daily energy expenditure: BMR scaled by activity level.
    static func tdee(for profile: UserProfile, on date: Date, calendar: Calendar = .current) -> Double {
        let bmr = bmr(
            weightKg: profile.weightKg,
            heightCm: profile.heightCm,
            ageYears: profile.age(on: date, calendar: calendar),
            sex: profile.sex
        )
        return bmr * profile.activityLevel.multiplier
    }

    /// Daily calorie goal, rounded to the nearest whole calorie and floored at
    /// `minimumDailyCalories`.
    static func dailyCalorieGoal(for profile: UserProfile, on date: Date, calendar: Calendar = .current) -> Double {
        let target = tdee(for: profile, on: date, calendar: calendar) + profile.goal.calorieAdjustment
        return max(minimumDailyCalories, target.rounded())
    }

    /// Splits a calorie goal into macros: protein by body weight, a fixed share
    /// for fat, and whatever remains for carbohydrates (never negative).
    static func macroTargets(for profile: UserProfile, calorieGoal: Double) -> MacroTargets {
        let protein = profile.weightKg * profile.goal.proteinGramsPerKg
        let fat = calorieGoal * fatCalorieShare / caloriesPerGramFat
        let remaining = calorieGoal - protein * caloriesPerGramProtein - fat * caloriesPerGramFat
        let carbohydrates = max(0, remaining / caloriesPerGramCarbohydrate)
        return MacroTargets(
            proteinG: protein.rounded(),
            carbohydratesG: carbohydrates.rounded(),
            fatG: fat.rounded()
        )
    }
}
