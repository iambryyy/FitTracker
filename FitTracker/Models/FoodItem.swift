//
//  FoodItem.swift
//  FitTracker
//

import Foundation

/// Nutrition facts for one food, as returned by the CalorieNinjas API.
struct FoodItem: Codable, Hashable, Sendable {
    var name: String
    var calories: Double
    var servingSizeG: Double
    var fatTotalG: Double
    var fatSaturatedG: Double
    var proteinG: Double
    var sodiumMg: Double
    var potassiumMg: Double
    var cholesterolMg: Double
    var carbohydratesTotalG: Double
    var fiberG: Double
    var sugarG: Double

    enum CodingKeys: String, CodingKey {
        case name
        case calories
        case servingSizeG = "serving_size_g"
        case fatTotalG = "fat_total_g"
        case fatSaturatedG = "fat_saturated_g"
        case proteinG = "protein_g"
        case sodiumMg = "sodium_mg"
        case potassiumMg = "potassium_mg"
        case cholesterolMg = "cholesterol_mg"
        case carbohydratesTotalG = "carbohydrates_total_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
    }

    init(
        name: String,
        calories: Double,
        servingSizeG: Double = 100,
        fatTotalG: Double = 0,
        fatSaturatedG: Double = 0,
        proteinG: Double = 0,
        sodiumMg: Double = 0,
        potassiumMg: Double = 0,
        cholesterolMg: Double = 0,
        carbohydratesTotalG: Double = 0,
        fiberG: Double = 0,
        sugarG: Double = 0
    ) {
        self.name = name
        self.calories = calories
        self.servingSizeG = servingSizeG
        self.fatTotalG = fatTotalG
        self.fatSaturatedG = fatSaturatedG
        self.proteinG = proteinG
        self.sodiumMg = sodiumMg
        self.potassiumMg = potassiumMg
        self.cholesterolMg = cholesterolMg
        self.carbohydratesTotalG = carbohydratesTotalG
        self.fiberG = fiberG
        self.sugarG = sugarG
    }

    /// `name` and `calories` are required. Every other field falls back to zero
    /// when it is missing or not a number, so one odd field in an API response
    /// does not throw away the whole result.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        calories = try container.decode(Double.self, forKey: .calories)
        servingSizeG = container.lossyDouble(forKey: .servingSizeG)
        fatTotalG = container.lossyDouble(forKey: .fatTotalG)
        fatSaturatedG = container.lossyDouble(forKey: .fatSaturatedG)
        proteinG = container.lossyDouble(forKey: .proteinG)
        sodiumMg = container.lossyDouble(forKey: .sodiumMg)
        potassiumMg = container.lossyDouble(forKey: .potassiumMg)
        cholesterolMg = container.lossyDouble(forKey: .cholesterolMg)
        carbohydratesTotalG = container.lossyDouble(forKey: .carbohydratesTotalG)
        fiberG = container.lossyDouble(forKey: .fiberG)
        sugarG = container.lossyDouble(forKey: .sugarG)
    }

    /// Name with the first letter of each word capitalised, for display.
    var displayName: String { name.capitalized }
}

private extension KeyedDecodingContainer {
    func lossyDouble(forKey key: Key) -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let text = try? decode(String.self, forKey: key), let value = Double(text) { return value }
        return 0
    }
}

/// Top-level shape of a CalorieNinjas `/v1/nutrition` response.
struct FoodSearchResponse: Codable, Sendable {
    var items: [FoodItem]
}
