//
//  ProfileDraftTests.swift
//  FitTrackerTests
//

import Foundation
import Testing
@testable import FitTracker

@Suite("ProfileDraft")
struct ProfileDraftTests {

    private func validMetricDraft() -> ProfileDraft {
        var draft = ProfileDraft(now: TestClock.now, calendar: TestClock.calendar)
        draft.name = "Sam"
        draft.unitSystem = .metric
        draft.heightCmText = "175"
        draft.weightText = "70"
        return draft
    }

    private func validate(_ draft: ProfileDraft) -> Result<UserProfile, ProfileValidationFailure> {
        draft.validate(now: TestClock.now, calendar: TestClock.calendar)
    }

    private func errors(_ draft: ProfileDraft) -> [ProfileValidationError] {
        if case .failure(let failure) = validate(draft) { return failure.errors }
        return []
    }

    // MARK: Happy paths

    @Test("A new draft defaults to imperial units and a 25-year-old")
    func defaults() {
        let draft = ProfileDraft(now: TestClock.now, calendar: TestClock.calendar)
        #expect(draft.unitSystem == .imperial)
        #expect(draft.birthDate == TestClock.date(2000, 6, 15, hour: 12))
    }

    @Test("Valid metric input produces a profile")
    func validMetric() throws {
        let profile = try validate(validMetricDraft()).get()
        #expect(profile.name == "Sam")
        #expect(profile.heightCm == 175)
        #expect(profile.weightKg == 70)
        #expect(profile.unitSystem == .metric)
    }

    @Test("Imperial input is stored in metric")
    func validImperial() throws {
        var draft = ProfileDraft(now: TestClock.now, calendar: TestClock.calendar)
        draft.name = "Sam"
        draft.heightFeetText = "5"
        draft.heightInchesText = "11"
        draft.weightText = "170"

        let profile = try validate(draft).get()
        #expect(isClose(profile.heightCm, 180.34))
        #expect(isClose(profile.weightKg, 77.11))
        #expect(profile.unitSystem == .imperial)
    }

    @Test("Blank inches means zero inches")
    func blankInches() throws {
        var draft = ProfileDraft(now: TestClock.now, calendar: TestClock.calendar)
        draft.name = "Sam"
        draft.heightFeetText = "6"
        draft.weightText = "170"
        #expect(isClose(try validate(draft).get().heightCm, 182.88))
    }

    @Test("Surrounding whitespace is trimmed from the name")
    func trimsName() throws {
        var draft = validMetricDraft()
        draft.name = "  Sam Lee \n"
        #expect(try validate(draft).get().name == "Sam Lee")
    }

    @Test("A comma is accepted as the decimal mark")
    func commaDecimal() throws {
        var draft = validMetricDraft()
        draft.weightText = "72,5"
        #expect(try validate(draft).get().weightKg == 72.5)
    }

    // MARK: Validation errors

    @Test("An empty draft reports every missing field, in form order")
    func emptyDraft() {
        let draft = ProfileDraft(now: TestClock.now, calendar: TestClock.calendar)
        #expect(errors(draft) == [.nameMissing, .heightNotANumber, .weightNotANumber])
    }

    @Test("A whitespace-only name is missing")
    func whitespaceName() {
        var draft = validMetricDraft()
        draft.name = "   "
        #expect(errors(draft) == [.nameMissing])
    }

    @Test("Non-numeric text is rejected", arguments: ["abc", "", " ", "1.2.3", "12kg", "nan", "inf"])
    func nonNumeric(text: String) {
        var draft = validMetricDraft()
        draft.heightCmText = text
        draft.weightText = text
        #expect(errors(draft) == [.heightNotANumber, .weightNotANumber])
    }

    @Test("Non-numeric inches invalidate the whole height")
    func nonNumericInches() {
        var draft = ProfileDraft(now: TestClock.now, calendar: TestClock.calendar)
        draft.name = "Sam"
        draft.heightFeetText = "5"
        draft.heightInchesText = "x"
        draft.weightText = "170"
        #expect(errors(draft) == [.heightNotANumber])
    }

    @Test("Height limits are inclusive", arguments: [
        ("89.9", false), ("90", true), ("250", true), ("250.1", false), ("-175", false), ("0", false)
    ])
    func heightBoundaries(text: String, isValid: Bool) {
        var draft = validMetricDraft()
        draft.heightCmText = text
        #expect(errors(draft) == (isValid ? [] : [.heightOutOfRange]))
    }

    @Test("Weight limits are inclusive", arguments: [
        ("24.9", false), ("25", true), ("350", true), ("350.1", false), ("-70", false), ("0", false)
    ])
    func weightBoundaries(text: String, isValid: Bool) {
        var draft = validMetricDraft()
        draft.weightText = text
        #expect(errors(draft) == (isValid ? [] : [.weightOutOfRange]))
    }

    @Test("Age limits are inclusive and measured to the day", arguments: [
        // TestClock.now is 15 June 2025.
        (TestClock.date(2012, 6, 15), true),   // 13 today
        (TestClock.date(2012, 6, 16), false),  // 13 tomorrow
        (TestClock.date(1904, 6, 16), true),   // 120, turns 121 tomorrow
        (TestClock.date(1904, 6, 15), false),  // 121 today
        (TestClock.date(2026, 1, 1), false)    // born in the future
    ])
    func ageBoundaries(birthDate: Date, isValid: Bool) {
        var draft = validMetricDraft()
        draft.birthDate = birthDate
        #expect(errors(draft) == (isValid ? [] : [.ageOutOfRange]))
    }

    @Test("Every validation error has a user-facing message")
    func messages() {
        for error in ProfileValidationError.allCases {
            #expect(!error.message.isEmpty)
        }
    }

    // MARK: Unit switching

    @Test("Switching to imperial converts what was typed")
    func switchToImperial() {
        var draft = validMetricDraft()
        draft.heightCmText = "180"
        draft.weightText = "80"
        draft.switchUnits(to: .imperial)

        #expect(draft.unitSystem == .imperial)
        #expect(draft.heightFeetText == "5")
        #expect(draft.heightInchesText == "11")
        #expect(draft.weightText == "176.4")
        #expect(draft.heightCmText.isEmpty)
    }

    @Test("Switching to metric converts what was typed")
    func switchToMetric() {
        var draft = ProfileDraft(now: TestClock.now, calendar: TestClock.calendar)
        draft.heightFeetText = "5"
        draft.heightInchesText = "11"
        draft.weightText = "170"
        draft.switchUnits(to: .metric)

        #expect(draft.heightCmText == "180.3")
        #expect(draft.weightText == "77.1")
        #expect(draft.heightFeetText.isEmpty)
        #expect(draft.heightInchesText.isEmpty)
    }

    @Test("Switching units leaves unparseable fields blank instead of guessing")
    func switchWithInvalidInput() {
        var draft = validMetricDraft()
        draft.heightCmText = "tall"
        draft.weightText = ""
        draft.switchUnits(to: .imperial)

        #expect(draft.heightFeetText.isEmpty)
        #expect(draft.heightInchesText.isEmpty)
        #expect(draft.weightText.isEmpty)
    }

    @Test("Switching to the current unit system changes nothing")
    func switchToSameUnits() {
        let original = validMetricDraft()
        var draft = original
        draft.switchUnits(to: .metric)
        #expect(draft == original)
    }

    // MARK: Editing an existing profile

    @Test("A draft built from a profile validates back to the same profile")
    func roundTripsProfile() throws {
        let draft = ProfileDraft(profile: .reference)
        #expect(draft.heightCmText == "180")
        #expect(draft.weightText == "80")
        #expect(try validate(draft).get() == UserProfile.reference)
    }

    @Test("Numbers are shown with at most one decimal place", arguments: [
        (80.0, "80"), (176.37, "176.4"), (72.5, "72.5"), (99.96, "100"), (0.04, "0")
    ])
    func numberText(value: Double, expected: String) {
        #expect(ProfileDraft.text(from: value) == expected)
    }
}
