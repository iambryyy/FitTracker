//
//  ProfileDraft.swift
//  FitTracker
//

import Foundation

enum ProfileValidationError: Error, Equatable, CaseIterable, Identifiable, Sendable {
    case nameMissing
    case heightNotANumber
    case heightOutOfRange
    case weightNotANumber
    case weightOutOfRange
    case ageOutOfRange

    var id: Self { self }

    var message: String {
        switch self {
        case .nameMissing: return "Enter your name."
        case .heightNotANumber: return "Enter your height as a number."
        case .heightOutOfRange: return "Height must be between 90 and 250 cm (3 ft and 8 ft 2 in)."
        case .weightNotANumber: return "Enter your weight as a number."
        case .weightOutOfRange: return "Weight must be between 25 and 350 kg (55 and 770 lb)."
        case .ageOutOfRange: return "You must be between 13 and 120 years old."
        }
    }
}

struct ProfileValidationFailure: Error, Equatable {
    let errors: [ProfileValidationError]
}

/// The editable, text-backed form of a `UserProfile`. Holds exactly what the
/// user typed and turns it into a validated profile on demand.
struct ProfileDraft: Equatable {
    static let heightRangeCm = 90.0...250.0
    static let weightRangeKg = 25.0...350.0
    static let ageRange = 13...120
    static let defaultAge = 25

    var name = ""
    var sex: BiologicalSex = .female
    var birthDate: Date
    var unitSystem: UnitSystem = .imperial
    var heightCmText = ""
    var heightFeetText = ""
    var heightInchesText = ""
    var weightText = ""
    var activityLevel: ActivityLevel = .moderate
    var goal: FitnessGoal = .maintain

    init(now: Date = Date(), calendar: Calendar = .current) {
        birthDate = calendar.date(byAdding: .year, value: -Self.defaultAge, to: now) ?? now
    }

    init(profile: UserProfile) {
        name = profile.name
        sex = profile.sex
        birthDate = profile.birthDate
        unitSystem = profile.unitSystem
        activityLevel = profile.activityLevel
        goal = profile.goal
        setHeight(cm: profile.heightCm)
        setWeight(kg: profile.weightKg)
    }

    // MARK: Parsed values

    /// Height in centimetres, or `nil` if the height fields do not parse.
    var heightCm: Double? {
        switch unitSystem {
        case .metric:
            return Self.number(from: heightCmText)
        case .imperial:
            guard let feet = Self.number(from: heightFeetText) else { return nil }
            // An empty inches field means zero; anything else must be a number.
            let inchesText = heightInchesText.trimmingCharacters(in: .whitespaces)
            guard let inches = inchesText.isEmpty ? 0 : Self.number(from: inchesText) else { return nil }
            return UnitConversion.centimeters(feet: feet, inches: inches)
        }
    }

    /// Weight in kilograms, or `nil` if the weight field does not parse.
    var weightKg: Double? {
        guard let value = Self.number(from: weightText) else { return nil }
        switch unitSystem {
        case .metric: return value
        case .imperial: return UnitConversion.kilograms(fromPounds: value)
        }
    }

    // MARK: Validation

    func validate(now: Date = Date(), calendar: Calendar = .current) -> Result<UserProfile, ProfileValidationFailure> {
        var errors: [ProfileValidationError] = []

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { errors.append(.nameMissing) }

        let height = heightCm
        if let height {
            if !Self.heightRangeCm.contains(height) { errors.append(.heightOutOfRange) }
        } else {
            errors.append(.heightNotANumber)
        }

        let weight = weightKg
        if let weight {
            if !Self.weightRangeKg.contains(weight) { errors.append(.weightOutOfRange) }
        } else {
            errors.append(.weightNotANumber)
        }

        let age = calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0
        if !Self.ageRange.contains(age) { errors.append(.ageOutOfRange) }

        guard errors.isEmpty, let height, let weight else {
            return .failure(ProfileValidationFailure(errors: errors))
        }
        return .success(UserProfile(
            name: trimmedName,
            sex: sex,
            birthDate: birthDate,
            heightCm: height,
            weightKg: weight,
            activityLevel: activityLevel,
            goal: goal,
            unitSystem: unitSystem
        ))
    }

    // MARK: Unit switching

    /// Switches unit system, converting whatever is already typed so the user
    /// does not have to re-enter it. Fields that do not parse are left blank.
    mutating func switchUnits(to newSystem: UnitSystem) {
        guard newSystem != unitSystem else { return }
        let height = heightCm
        let weight = weightKg
        unitSystem = newSystem
        heightCmText = ""
        heightFeetText = ""
        heightInchesText = ""
        weightText = ""
        if let height { setHeight(cm: height) }
        if let weight { setWeight(kg: weight) }
    }

    private mutating func setHeight(cm: Double) {
        switch unitSystem {
        case .metric:
            heightCmText = Self.text(from: cm)
        case .imperial:
            let parts = UnitConversion.feetAndInches(fromCentimeters: cm)
            heightFeetText = String(parts.feet)
            heightInchesText = String(parts.inches)
        }
    }

    private mutating func setWeight(kg: Double) {
        switch unitSystem {
        case .metric: weightText = Self.text(from: kg)
        case .imperial: weightText = Self.text(from: UnitConversion.pounds(fromKilograms: kg))
        }
    }

    // MARK: Number formatting

    /// Parses user-typed numbers, accepting either `.` or `,` as the decimal mark.
    static func number(from text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    /// At most one decimal place, with a trailing `.0` dropped.
    static func text(from value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
