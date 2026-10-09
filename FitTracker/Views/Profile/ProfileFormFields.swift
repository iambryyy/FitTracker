//
//  ProfileFormFields.swift
//  FitTracker
//

import SwiftUI

/// The profile inputs, shared by onboarding and the profile tab.
struct ProfileFormFields: View {
    @Binding var draft: ProfileDraft
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, heightCm, heightFeet, heightInches, weight
    }

    var body: some View {
        VStack(spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("Name")
                    TextField("Your name", text: $draft.name)
                        .textContentType(.givenName)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .name)
                        .accessibilityIdentifier(AccessibilityID.ProfileForm.nameField)

                    fieldLabel("Sex (used for the calorie estimate)")
                    Picker("Sex", selection: $draft.sex) {
                        ForEach(BiologicalSex.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(AccessibilityID.ProfileForm.sexPicker)

                    DatePicker(
                        "Date of birth",
                        selection: $draft.birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .font(.subheadline)
                    .accessibilityIdentifier(AccessibilityID.ProfileForm.birthDatePicker)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("Units")
                    Picker("Units", selection: unitBinding) {
                        ForEach(UnitSystem.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(AccessibilityID.ProfileForm.unitPicker)

                    fieldLabel("Height")
                    heightFields

                    fieldLabel("Weight")
                    numberField(
                        draft.unitSystem == .metric ? "kg" : "lb",
                        text: $draft.weightText,
                        keyboard: .decimalPad,
                        field: .weight,
                        id: AccessibilityID.ProfileForm.weightField
                    )
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("Activity level")
                    Picker("Activity level", selection: $draft.activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier(AccessibilityID.ProfileForm.activityPicker)
                    Text(draft.activityLevel.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    fieldLabel("Weight goal")
                    Picker("Weight goal", selection: $draft.goal) {
                        ForEach(FitnessGoal.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(AccessibilityID.ProfileForm.goalPicker)
                }
            }
        }
        .toolbar {
            // Number pads have no return key, so give every field a way out.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .accessibilityIdentifier(AccessibilityID.ProfileForm.keyboardDoneButton)
            }
        }
    }

    /// Routes unit changes through the draft so typed values are converted.
    private var unitBinding: Binding<UnitSystem> {
        Binding(
            get: { draft.unitSystem },
            set: { draft.switchUnits(to: $0) }
        )
    }

    @ViewBuilder
    private var heightFields: some View {
        switch draft.unitSystem {
        case .metric:
            numberField("cm", text: $draft.heightCmText, keyboard: .decimalPad, field: .heightCm,
                        id: AccessibilityID.ProfileForm.heightCmField)
        case .imperial:
            HStack(spacing: 12) {
                numberField("ft", text: $draft.heightFeetText, keyboard: .numberPad, field: .heightFeet,
                            id: AccessibilityID.ProfileForm.heightFeetField)
                numberField("in", text: $draft.heightInchesText, keyboard: .numberPad, field: .heightInches,
                            id: AccessibilityID.ProfileForm.heightInchesField)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func numberField(
        _ unit: String, text: Binding<String>, keyboard: UIKeyboardType, field: Field, id: String
    ) -> some View {
        HStack {
            TextField("0", text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: field)
                .accessibilityIdentifier(id)
                .accessibilityLabel(unit)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
                .accessibilityHidden(true)
        }
    }
}

/// Validation messages plus a live preview of the resulting calorie goal.
struct ProfileFormStatus: View {
    var draft: ProfileDraft
    var errors: [ProfileValidationError]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(errors) { error in
                        Label(error.message, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.ProfileForm.errors)
            } else if case .success(let profile) = draft.validate() {
                let goal = NutritionCalculator.dailyCalorieGoal(for: profile, on: Date())
                Text("Daily goal: \(goal.wholeNumberText) kcal")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.ProfileForm.goalPreview)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
