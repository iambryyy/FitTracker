//
//  DiaryStore.swift
//  FitTracker
//

import Foundation
import Observation

/// The single source of truth for logged food. Every screen reads from here,
/// so totals update everywhere the moment an entry is added or removed.
@MainActor
@Observable
final class DiaryStore {
    static let storageKey = "fittracker.diary.v1"

    private(set) var entries: [DiaryEntry] = []
    /// True when saved data existed but could not be decoded. The unreadable
    /// data is left in place until the next successful save.
    private(set) var didFailToLoad = false

    @ObservationIgnored private let storage: KeyValueStoring
    @ObservationIgnored private let calendar: Calendar

    init(storage: KeyValueStoring, calendar: Calendar = .current) {
        self.storage = storage
        self.calendar = calendar
        load()
    }

    // MARK: Queries

    /// Entries logged on the same calendar day as `date`, oldest first.
    func entries(on date: Date) -> [DiaryEntry] {
        entries
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    func entries(on date: Date, meal: MealType) -> [DiaryEntry] {
        entries(on: date).filter { $0.meal == meal }
    }

    func totals(on date: Date) -> NutritionTotals {
        NutritionTotals(entries(on: date))
    }

    // MARK: Mutations

    @discardableResult
    func add(_ food: FoodItem, servings: Double = 1, meal: MealType, at date: Date) -> DiaryEntry {
        let entry = DiaryEntry(food: food, servings: max(servings, 0), meal: meal, loggedAt: date)
        entries.append(entry)
        save()
        return entry
    }

    func remove(id: DiaryEntry.ID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries.remove(at: index)
        save()
    }

    func removeAll() {
        entries = []
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = storage.data(forKey: Self.storageKey) else { return }
        do {
            entries = try JSONDecoder().decode([DiaryEntry].self, from: data)
        } catch {
            entries = []
            didFailToLoad = true
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        storage.setData(data, forKey: Self.storageKey)
        didFailToLoad = false
    }
}
