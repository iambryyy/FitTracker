//
//  CalorieNinjasService.swift
//  FitTracker
//

import Foundation

/// Live food search backed by https://calorieninjas.com.
///
/// The query is natural language ("2 eggs and a slice of toast"); the API
/// returns one item per food it recognises, scaled to the quantity asked for.
struct CalorieNinjasService: NutritionService {
    static let defaultBaseURL = URL(string: "https://api.calorieninjas.com/v1/nutrition")!
    static let apiKeyHeader = "X-Api-Key"

    let apiKey: String
    let session: URLSession
    let baseURL: URL

    init(apiKey: String, session: URLSession = .shared, baseURL: URL = CalorieNinjasService.defaultBaseURL) {
        self.apiKey = apiKey
        self.session = session
        self.baseURL = baseURL
    }

    func makeRequest(query: String) throws -> URLRequest {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NutritionServiceError.emptyQuery }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NutritionServiceError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "query", value: trimmed)]
        guard let url = components.url else { throw NutritionServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    func search(_ query: String) async throws -> [FoodItem] {
        let request = try makeRequest(query: query)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw NutritionServiceError.network(error.code)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NutritionServiceError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw NutritionServiceError.unauthorized
        case 429: throw NutritionServiceError.rateLimited
        default: throw NutritionServiceError.http(status: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(FoodSearchResponse.self, from: data).items
        } catch {
            throw NutritionServiceError.decoding
        }
    }
}
