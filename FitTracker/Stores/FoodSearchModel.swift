//
//  FoodSearchModel.swift
//  FitTracker
//

import Foundation
import Observation

/// Drives the food search screen: owns the query text and the single state the
/// screen renders.
@MainActor
@Observable
final class FoodSearchModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([FoodItem])
        case empty(query: String)
        case failed(message: String)
    }

    var query = ""
    private(set) var state: State = .idle

    @ObservationIgnored private let service: NutritionService
    /// Incremented for every search so a slow, superseded response can be
    /// recognised and dropped instead of overwriting newer results.
    @ObservationIgnored private var latestSearchID = 0

    init(service: NutritionService) {
        self.service = service
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        latestSearchID += 1
        let searchID = latestSearchID

        guard !trimmed.isEmpty else {
            state = .idle
            return
        }

        state = .loading
        do {
            let items = try await service.search(trimmed)
            guard searchID == latestSearchID else { return }
            state = items.isEmpty ? .empty(query: trimmed) : .loaded(items)
        } catch is CancellationError {
            guard searchID == latestSearchID else { return }
            state = .idle
        } catch {
            guard searchID == latestSearchID else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again."
            state = .failed(message: message)
        }
    }
}
