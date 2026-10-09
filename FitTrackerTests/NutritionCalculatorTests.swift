//
//  NutritionCalculatorTests.swift
//  FitTrackerTests
//

import Foundation
import Testing
@testable import FitTracker

@Suite("NutritionCalculator")
struct NutritionCalculatorTests {

    // MARK: BMI

    @Test("BMI is weight over height squared")
    func bmiValue() throws {
        let bmi = try #require(NutritionCalculator.bmi(weightKg: 80, heightCm: 180))
        #expect(isClose(bmi, 24.69))
    }

    @Test("BMI is nil for non-positive inputs", arguments: [
        (0.0, 180.0), (80.0, 0.0), (-5.0, 180.0), (80.0, -1.0)
    ])
    func bmiRejectsNonPositive(weightKg: Double, heightCm: Double) {
        #expect(NutritionCalculator.bmi(weightKg: weightKg, heightCm: heightCm) == nil)
    }

    @Test("BMI categories switch exactly at the WHO cut-offs", arguments: [
        (10.0, BMICategory.underweight),
        (18.49, .underweight),
        (18.5, .healthy),
        (24.99, .healthy),
        (25.0, .overweight),
        (29.99, .overweight),
        (30.0, .obese),
        (45.0, .obese)
    ])
    func bmiCategory(bmi: Double, expected: BMICategory) {
        #expect(BMICategory(bmi: bmi) == expected)
    }

    // MARK: BMR and TDEE

    @Test("Mifflin-St Jeor BMR", arguments: [
        (BiologicalSex.male, 1780.0),
        (BiologicalSex.female, 1614.0)
    ])
    func bmr(sex: BiologicalSex, expected: Double) {
        let bmr = NutritionCalculator.bmr(weightKg: 80, heightCm: 180, ageYears: 30, sex: sex)
        #expect(bmr == expected)
    }

    @Test("TDEE scales BMR by the activity multiplier", arguments: [
        (ActivityLevel.sedentary, 2136.0),
        (.light, 2447.5),
        (.moderate, 2759.0),
        (.veryActive, 3070.5),
        (.extraActive, 3382.0)
    ])
    func tdee(level: ActivityLevel, expected: Double) {
        var profile = UserProfile.reference
        profile.activityLevel = level
        let tdee = NutritionCalculator.tdee(for: profile, on: TestClock.now, calendar: TestClock.calendar)
        #expect(isClose(tdee, expected))
    }

    @Test("Age used for BMR changes on the birthday, not before")
    func ageRollsOverOnBirthday() {
        let profile = UserProfile.reference // born 15 June 1995
        let dayBefore = TestClock.date(2025, 6, 14)
        let birthday = TestClock.date(2025, 6, 15)
        #expect(profile.age(on: dayBefore, calendar: TestClock.calendar) == 29)
        #expect(profile.age(on: birthday, calendar: TestClock.calendar) == 30)
    }

    // MARK: Calorie goal

    @Test("Calorie goal applies the goal adjustment to TDEE", arguments: [
        (FitnessGoal.lose, 2259.0),
        (.maintain, 2759.0),
        (.gain, 3059.0)
    ])
    func calorieGoal(goal: FitnessGoal, expected: Double) {
        var profile = UserProfile.reference
        profile.goal = goal
        let result = NutritionCalculator.dailyCalorieGoal(for: profile, on: TestClock.now, calendar: TestClock.calendar)
        #expect(result == expected)
    }

    @Test("Calorie goal never drops below the safety floor")
    func calorieGoalFloor() {
        // BMR 926.5, TDEE 1111.8, minus 500 would be 611.8.
        let profile = UserProfile(
            name: "Pat", sex: .female, birthDate: TestClock.date(1965, 6, 15),
            heightCm: 150, weightKg: 45, activityLevel: .sedentary, goal: .lose, unitSystem: .metric
        )
        let result = NutritionCalculator.dailyCalorieGoal(for: profile, on: TestClock.now, calendar: TestClock.calendar)
        #expect(result == NutritionCalculator.minimumDailyCalories)
    }

    // MARK: Macros

    @Test("Macro targets: protein by body weight, 25% fat, carbs fill the rest")
    func macroTargets() {
        let macros = NutritionCalculator.macroTargets(for: .reference, calorieGoal: 2759)
        #expect(macros == MacroTargets(proteinG: 128, carbohydratesG: 389, fatG: 77))
    }

    @Test("Macro calories add back up to the calorie goal")
    func macrosSumToGoal() {
        let goal = 2759.0
        let macros = NutritionCalculator.macroTargets(for: .reference, calorieGoal: goal)
        let calories = macros.proteinG * 4 + macros.carbohydratesG * 4 + macros.fatG * 9
        // Each macro is rounded to a whole gram, so allow a few calories of drift.
        #expect(isClose(calories, goal, tolerance: 10))
    }

    @Test("Carbohydrate target is clamped at zero when protein and fat exceed the goal")
    func carbohydratesNeverNegative() {
        var profile = UserProfile.reference
        profile.weightKg = 200
        profile.goal = .lose
        let macros = NutritionCalculator.macroTargets(for: profile, calorieGoal: 1200)
        #expect(macros.carbohydratesG == 0)
        #expect(macros.proteinG == 400)
    }
}

@Suite("UnitConversion")
struct UnitConversionTests {

    @Test func poundsToKilograms() {
        #expect(isClose(UnitConversion.kilograms(fromPounds: 170), 77.11))
    }

    @Test func kilogramsToPounds() {
        #expect(isClose(UnitConversion.pounds(fromKilograms: 80), 176.37))
    }

    @Test func weightRoundTrips() {
        let pounds = UnitConversion.pounds(fromKilograms: 72.5)
        #expect(isClose(UnitConversion.kilograms(fromPounds: pounds), 72.5, tolerance: 1e-9))
    }

    @Test func feetAndInchesToCentimeters() {
        #expect(isClose(UnitConversion.centimeters(feet: 5, inches: 11), 180.34))
    }

    @Test("Centimetres to feet and inches rounds to the nearest inch", arguments: [
        (180.34, 5, 11),
        (152.4, 5, 0),
        (182.4, 6, 0),   // 71.8 in rounds up to 72 in, which must read 6'0", not 5'12"
        (181.0, 5, 11),
        (0.0, 0, 0)
    ])
    func centimetersToFeetAndInches(centimeters: Double, feet: Int, inches: Int) {
        let result = UnitConversion.feetAndInches(fromCentimeters: centimeters)
        #expect(result.feet == feet)
        #expect(result.inches == inches)
    }
}
