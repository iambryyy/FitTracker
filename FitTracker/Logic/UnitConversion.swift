//
//  UnitConversion.swift
//  FitTracker
//

import Foundation

enum UnitConversion {
    static let kilogramsPerPound = 0.45359237
    static let centimetersPerInch = 2.54
    static let inchesPerFoot = 12.0

    static func kilograms(fromPounds pounds: Double) -> Double {
        pounds * kilogramsPerPound
    }

    static func pounds(fromKilograms kilograms: Double) -> Double {
        kilograms / kilogramsPerPound
    }

    static func centimeters(feet: Double, inches: Double) -> Double {
        (feet * inchesPerFoot + inches) * centimetersPerInch
    }

    /// Whole feet and whole inches, rounded to the nearest inch. Rounding happens
    /// before the split so 182.4 cm reads 6 ft 0 in rather than 5 ft 12 in.
    static func feetAndInches(fromCentimeters centimeters: Double) -> (feet: Int, inches: Int) {
        let totalInches = Int((centimeters / centimetersPerInch).rounded())
        return (totalInches / Int(inchesPerFoot), totalInches % Int(inchesPerFoot))
    }
}
