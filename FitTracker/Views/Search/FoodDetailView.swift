//
//  FoodDetailView.swift
//  FitTracker
//

import SwiftUI

/// Nutrition facts for one search result, with servings and meal to log it under.
struct FoodDetailView: View {
    let food: FoodItem
    let date: Date
    var onAdd: (DiaryEntry) -> Void

    @Environment(DiaryStore.self) private var diaryStore
    @State private var servings = 1.0
    @State private var meal: MealType

    init(food: FoodItem, date: Date, onAdd: @escaping (DiaryEntry) -> Void) {
        self.food = food
        self.date = date
        self.onAdd = onAdd
        _meal = State(initialValue: MealType.suggested(for: Date()))
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Calories") {
                    Text("\((food.calories * servings).wholeNumberText) kcal")
                        .accessibilityIdentifier(AccessibilityID.FoodDetail.calories)
                }
                LabeledContent("Protein", value: grams(food.proteinG))
                LabeledContent("Carbohydrates", value: grams(food.carbohydratesTotalG))
                LabeledContent("Fat", value: grams(food.fatTotalG))
                LabeledContent("Fiber", value: grams(food.fiberG))
                LabeledContent("Sugar", value: grams(food.sugarG))
            } header: {
                Text("Per \((food.servingSizeG * servings).oneDecimalText) g")
            }

            Section {
                Stepper(value: $servings, in: 0.5...20, step: 0.5) {
                    LabeledContent("Servings", value: servings.oneDecimalText)
                }
                .accessibilityIdentifier(AccessibilityID.FoodDetail.servingsStepper)

                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier(AccessibilityID.FoodDetail.mealPicker)
            }

            Section {
                Button("Add to Diary") {
                    onAdd(diaryStore.add(food, servings: servings, meal: meal, at: date))
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier(AccessibilityID.FoodDetail.addButton)
            }
        }
        .navigationTitle(food.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func grams(_ value: Double) -> String {
        "\((value * servings).oneDecimalText) g"
    }
}
