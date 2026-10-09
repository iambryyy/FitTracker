//
//  DiaryView.swift
//  FitTracker
//

import SwiftUI

/// Day-by-day food log, grouped by meal. Swipe a row to delete it.
struct DiaryView: View {
    @Environment(DiaryStore.self) private var diaryStore

    @State private var selectedDate = Date()
    @State private var isSearching = false

    private var isShowingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dayPicker
                entryList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Food Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSearching = true
                    } label: {
                        Label("Add food", systemImage: "plus")
                    }
                    .accessibilityIdentifier(AccessibilityID.Diary.addButton)
                }
            }
            .sheet(isPresented: $isSearching) {
                FoodSearchView(date: logDate)
            }
        }
    }

    /// Entries added for today get the real time; entries added for another day
    /// are stamped at noon on that day.
    private var logDate: Date {
        if isShowingToday { return Date() }
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
    }

    private var dayPicker: some View {
        HStack {
            Button {
                shiftDay(by: -1)
            } label: {
                Label("Previous day", systemImage: "chevron.left").labelStyle(.iconOnly)
            }
            .accessibilityIdentifier(AccessibilityID.Diary.previousDayButton)

            Spacer()
            VStack(spacing: 2) {
                Text(isShowingToday ? "Today" : selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .accessibilityIdentifier(AccessibilityID.Diary.dateLabel)
                Text("\(diaryStore.totals(on: selectedDate).calories.wholeNumberText) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityIdentifier(AccessibilityID.Diary.totalCalories)
            }
            Spacer()

            Button {
                shiftDay(by: 1)
            } label: {
                Label("Next day", systemImage: "chevron.right").labelStyle(.iconOnly)
            }
            .disabled(isShowingToday)
            .accessibilityIdentifier(AccessibilityID.Diary.nextDayButton)
        }
        .padding(16)
    }

    @ViewBuilder
    private var entryList: some View {
        if diaryStore.entries(on: selectedDate).isEmpty {
            ContentUnavailableView {
                Label("No food logged", systemImage: "book")
            } description: {
                Text("Tap + to add what you ate.")
            }
            .accessibilityIdentifier(AccessibilityID.Diary.emptyState)
        } else {
            List {
                ForEach(MealType.allCases) { meal in
                    let entries = diaryStore.entries(on: selectedDate, meal: meal)
                    if !entries.isEmpty {
                        Section(meal.title) {
                            ForEach(entries) { entry in
                                DiaryRow(entry: entry)
                            }
                            .onDelete { offsets in
                                for index in offsets { diaryStore.remove(id: entries[index].id) }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func shiftDay(by days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = min(date, Date())
    }
}

private struct DiaryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.food.displayName)
                Text("P \(entry.proteinG.oneDecimalText) g · C \(entry.carbohydratesG.oneDecimalText) g · F \(entry.fatG.oneDecimalText) g")
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

#Preview {
    let diaryStore = DiaryStore(storage: InMemoryKeyValueStore())
    diaryStore.add(FoodItem(name: "banana", calories: 89, proteinG: 1.1, carbohydratesTotalG: 22.8), meal: .breakfast, at: Date())
    diaryStore.add(FoodItem(name: "chicken breast", calories: 165, proteinG: 31), meal: .lunch, at: Date())
    return DiaryView()
        .environment(diaryStore)
}
