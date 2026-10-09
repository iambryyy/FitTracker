//
//  DashboardView.swift
//  FitTracker
//

import SwiftUI

/// Today at a glance: calories against the goal, macros, and what was logged.
struct DashboardView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(DiaryStore.self) private var diaryStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var today = Date()
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = profileStore.profile {
                    content(for: profile)
                        .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .sheet(isPresented: $isSearching) {
                FoodSearchView(date: today)
            }
        }
        .onChange(of: scenePhase) {
            // Roll over to the new day if the app was left open overnight.
            if scenePhase == .active { today = Date() }
        }
    }

    @ViewBuilder
    private func content(for profile: UserProfile) -> some View {
        let goal = NutritionCalculator.dailyCalorieGoal(for: profile, on: today)
        let macros = NutritionCalculator.macroTargets(for: profile, calorieGoal: goal)
        let totals = diaryStore.totals(on: today)
        let entries = diaryStore.entries(on: today)

        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hi, \(profile.name)")
                    .font(.title2.bold())
                    .accessibilityIdentifier(AccessibilityID.Dashboard.greeting)
                Text(today.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Card {
                VStack(spacing: 20) {
                    CalorieRing(consumed: totals.calories, goal: goal)
                        .frame(width: 200, height: 200)
                        .frame(maxWidth: .infinity)

                    HStack {
                        stat("Eaten", value: totals.calories, id: AccessibilityID.Dashboard.caloriesConsumed)
                        Divider().frame(height: 32)
                        stat("Goal", value: goal, id: AccessibilityID.Dashboard.calorieGoal)
                    }

                    HStack(spacing: 16) {
                        MacroBar(title: "Protein", consumed: totals.proteinG, target: macros.proteinG, tint: .ftOrange)
                        MacroBar(title: "Carbs", consumed: totals.carbohydratesG, target: macros.carbohydratesG, tint: .ftYellow)
                        MacroBar(title: "Fat", consumed: totals.fatG, target: macros.fatG, tint: .ftDeepTeal)
                    }
                }
            }

            Button {
                isSearching = true
            } label: {
                Label("Log Food", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.Dashboard.logFoodButton)

            if let bmi = NutritionCalculator.bmi(weightKg: profile.weightKg, heightCm: profile.heightCm) {
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Body mass index")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(BMICategory(bmi: bmi).title)
                                .font(.headline)
                        }
                        Spacer()
                        Text(bmi.oneDecimalText)
                            .font(.system(.title, design: .rounded).bold())
                            .foregroundStyle(.ftTeal)
                            .accessibilityIdentifier(AccessibilityID.Dashboard.bmiValue)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Logged today")
                        .font(.headline)
                    if entries.isEmpty {
                        Text("Nothing logged yet. Tap Log Food to add your first meal.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(AccessibilityID.Dashboard.emptyLog)
                    } else {
                        ForEach(entries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.food.displayName)
                                    Text(entry.meal.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(entry.calories.wholeNumberText) kcal")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func stat(_ title: String, value: Double, id: String) -> some View {
        VStack(spacing: 2) {
            Text(value.wholeNumberText)
                .font(.title3.bold())
                .monospacedDigit()
                .accessibilityIdentifier(id)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let storage = InMemoryKeyValueStore()
    let profileStore = ProfileStore(storage: storage)
    profileStore.save(.sample())
    let diaryStore = DiaryStore(storage: storage)
    diaryStore.add(FoodItem(name: "banana", calories: 89, proteinG: 1.1, carbohydratesTotalG: 22.8), meal: .breakfast, at: Date())
    return DashboardView()
        .environment(profileStore)
        .environment(diaryStore)
}
