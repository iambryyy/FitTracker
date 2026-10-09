//
//  FoodSearchView.swift
//  FitTracker
//

import SwiftUI

/// Sheet for finding a food and adding it to the diary on `date`.
struct FoodSearchView: View {
    let date: Date

    @Environment(\.nutritionService) private var nutritionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // The model needs the service from the environment, which is only
        // available once `body` runs, so it is created one level down.
        FoodSearchContent(model: FoodSearchModel(service: nutritionService), date: date, dismiss: { dismiss() })
    }
}

private struct FoodSearchContent: View {
    @State var model: FoodSearchModel
    let date: Date
    let dismiss: () -> Void

    @Environment(\.searchSource) private var searchSource
    @State private var path: [FoodItem] = []
    @State private var lastAddedName: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                searchBar
                if let lastAddedName {
                    Label("Added \(lastAddedName)", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.ftTeal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .accessibilityIdentifier(AccessibilityID.Search.addedBanner)
                }
                results
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss)
                        .accessibilityIdentifier(AccessibilityID.Search.doneButton)
                }
            }
            .navigationDestination(for: FoodItem.self) { food in
                FoodDetailView(food: food, date: date) { entry in
                    lastAddedName = entry.food.displayName
                    path = []
                }
            }
        }
        .onAppear { isFieldFocused = true }
        .onDisappear { searchTask?.cancel() }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("e.g. 2 eggs and toast", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isFieldFocused)
                .onSubmit(runSearch)
                .accessibilityIdentifier(AccessibilityID.Search.field)

            Button("Search", action: runSearch)
                .buttonStyle(.borderedProminent)
                .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier(AccessibilityID.Search.submitButton)
        }
        .padding(16)
    }

    @ViewBuilder
    private var results: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView {
                Label("Search for a food", systemImage: "magnifyingglass")
            } description: {
                Text(sourceNote)
                    .accessibilityIdentifier(AccessibilityID.Search.sourceNote)
            }

        case .loading:
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(AccessibilityID.Search.loading)

        case .loaded(let items):
            List(Array(items.enumerated()), id: \.offset) { index, food in
                NavigationLink(value: food) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.displayName)
                            Text("\(food.servingSizeG.oneDecimalText) g serving")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(food.calories.wholeNumberText) kcal")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Search.result(index))
            }
            .listStyle(.insetGrouped)

        case .empty(let query):
            ContentUnavailableView {
                Label("No results", systemImage: "fork.knife")
            } description: {
                Text("Nothing matched “\(query)”. Try a simpler name.")
            }
            .accessibilityIdentifier(AccessibilityID.Search.emptyState)

        case .failed(let message):
            ContentUnavailableView {
                Label("Search failed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
                    .accessibilityIdentifier(AccessibilityID.Search.errorState)
            } actions: {
                Button("Try Again", action: runSearch)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(AccessibilityID.Search.retryButton)
            }
        }
    }

    private var sourceNote: String {
        switch searchSource {
        case .live:
            return "Describe what you ate in plain English."
        case .offlineSamples, .alwaysFailing:
            return "Using the built-in sample food list. Add a CalorieNinjas API key to search everything."
        }
    }

    private func runSearch() {
        lastAddedName = nil
        searchTask?.cancel()
        searchTask = Task { await model.search() }
    }
}

#Preview {
    FoodSearchView(date: Date())
        .environment(DiaryStore(storage: InMemoryKeyValueStore()))
        .environment(\.nutritionService, OfflineNutritionService(foods: [
            FoodItem(name: "banana", calories: 89),
            FoodItem(name: "apple", calories: 52)
        ]))
}
