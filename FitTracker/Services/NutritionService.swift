//
//  NutritionService.swift
//  FitTracker
//

import Foundation

/// Anything that can turn a free-text query into nutrition facts.
protocol NutritionService: Sendable {
    func search(_ query: String) async throws -> [FoodItem]
}

enum NutritionServiceError: Error, Equatable, LocalizedError {
    case emptyQuery
    case unauthorized
    case rateLimited
    case http(status: Int)
    case invalidResponse
    case decoding
    case network(URLError.Code)

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Type a food to search for."
        case .unauthorized:
            return "The nutrition service rejected the API key. Check Config/Secrets.xcconfig."
        case .rateLimited:
            return "Too many searches right now. Try again in a minute."
        case .http(let status):
            return "The nutrition service returned an error (HTTP \(status))."
        case .invalidResponse, .decoding:
            return "The nutrition service sent a response FitTracker could not read."
        case .network(let code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "You appear to be offline. Check your connection and try again."
            case .timedOut:
                return "The search timed out. Try again."
            default:
                return "Could not reach the nutrition service. Try again."
            }
        }
    }
}
