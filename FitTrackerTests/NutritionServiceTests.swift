//
//  NutritionServiceTests.swift
//  FitTrackerTests
//

import Foundation
import Testing
@testable import FitTracker

@Suite("FoodItem decoding")
struct FoodItemDecodingTests {

    private func decode(_ json: String) throws -> FoodItem {
        try JSONDecoder().decode(FoodItem.self, from: Data(json.utf8))
    }

    @Test("Decodes a full CalorieNinjas item")
    func fullItem() throws {
        let item = try decode("""
        {"name": "rice", "calories": 127.4, "serving_size_g": 100, "fat_total_g": 0.3,
         "fat_saturated_g": 0.1, "protein_g": 2.7, "sodium_mg": 1, "potassium_mg": 42,
         "cholesterol_mg": 0, "carbohydrates_total_g": 28.4, "fiber_g": 0.4, "sugar_g": 0.1}
        """)
        #expect(item.name == "rice")
        #expect(item.calories == 127.4)
        #expect(item.servingSizeG == 100)
        #expect(item.proteinG == 2.7)
        #expect(item.carbohydratesTotalG == 28.4)
        #expect(item.fatTotalG == 0.3)
    }

    @Test("Fractional milligram values decode (they used to be typed Int and fail)")
    func fractionalMilligrams() throws {
        let item = try decode(#"{"name": "egg", "calories": 147, "sodium_mg": 139.5, "cholesterol_mg": 371.2}"#)
        #expect(item.sodiumMg == 139.5)
        #expect(item.cholesterolMg == 371.2)
    }

    @Test("Missing optional fields default to zero")
    func missingOptionalFields() throws {
        let item = try decode(#"{"name": "mystery", "calories": 10}"#)
        #expect(item.proteinG == 0)
        #expect(item.fiberG == 0)
        #expect(item.servingSizeG == 0)
    }

    @Test("Numeric strings are accepted; non-numeric strings become zero")
    func stringFields() throws {
        let item = try decode(#"{"name": "x", "calories": 10, "protein_g": "12.5", "sugar_g": "premium only"}"#)
        #expect(item.proteinG == 12.5)
        #expect(item.sugarG == 0)
    }

    @Test("Name and calories are required", arguments: [
        #"{"calories": 10}"#,
        #"{"name": "x"}"#,
        #"{"name": "x", "calories": "lots"}"#,
        #"{}"#
    ])
    func requiredFields(json: String) {
        #expect(throws: DecodingError.self) { try decode(json) }
    }

    @Test("Encoding uses the API's snake_case keys and round-trips")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(FoodItem.banana)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["carbohydrates_total_g"] as? Double == 22.8)
        #expect(object["carbohydratesTotalG"] == nil)
        #expect(try JSONDecoder().decode(FoodItem.self, from: data) == FoodItem.banana)
    }

    @Test func displayNameIsCapitalised() {
        #expect(FoodItem.chicken.displayName == "Chicken Breast")
    }
}

// Serialized because every test shares the static StubURLProtocol handler.
@Suite("CalorieNinjasService", .serialized)
struct CalorieNinjasServiceTests {
    private let service: CalorieNinjasService

    init() {
        StubURLProtocol.reset()
        service = CalorieNinjasService(apiKey: "test-key", session: StubURLProtocol.makeSession())
    }

    // MARK: Request

    @Test("Request carries the API key header and a percent-encoded query")
    func requestShape() throws {
        let request = try service.makeRequest(query: "  2 eggs & toast  ")
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == "test-key")
        #expect(url.host == "api.calorieninjas.com")
        #expect(url.path == "/v1/nutrition")
        // Decoded value is the trimmed query; the raw URL must not contain a bare "&" or space.
        #expect(components.queryItems == [URLQueryItem(name: "query", value: "2 eggs & toast")])
        #expect(components.percentEncodedQuery == "query=2%20eggs%20%26%20toast")
    }

    @Test("Blank queries are rejected before any network call", arguments: ["", "   ", "\n\t"])
    func blankQuery(query: String) async {
        await #expect(throws: NutritionServiceError.emptyQuery) {
            try await service.search(query)
        }
        #expect(StubURLProtocol.recordedRequests.isEmpty)
    }

    // MARK: Responses

    @Test("A 200 response is decoded into food items")
    func success() async throws {
        StubURLProtocol.respond(status: 200, body: """
        {"items": [
          {"name": "egg", "calories": 147, "protein_g": 12.5},
          {"name": "toast", "calories": 293, "protein_g": 9}
        ]}
        """)

        let items = try await service.search("2 eggs and toast")

        #expect(items.map(\.name) == ["egg", "toast"])
        #expect(items.first?.proteinG == 12.5)
        #expect(StubURLProtocol.recordedRequests.count == 1)
        #expect(StubURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "X-Api-Key") == "test-key")
    }

    @Test("An empty item list is a successful, empty result")
    func noMatches() async throws {
        StubURLProtocol.respond(status: 200, body: #"{"items": []}"#)
        #expect(try await service.search("zzzz").isEmpty)
    }

    @Test("HTTP error statuses map to specific errors", arguments: [
        (400, NutritionServiceError.http(status: 400)),
        (401, .unauthorized),
        (403, .unauthorized),
        (404, .http(status: 404)),
        (429, .rateLimited),
        (500, .http(status: 500)),
        (503, .http(status: 503))
    ])
    func httpErrors(status: Int, expected: NutritionServiceError) async {
        StubURLProtocol.respond(status: status, body: #"{"error": "nope"}"#)
        await #expect(throws: expected) {
            try await service.search("apple")
        }
    }

    @Test("Unreadable bodies are reported as decoding errors", arguments: [
        "not json", "", "[]", #"{"items": "none"}"#, #"{"items": [{"calories": 5}]}"#
    ])
    func malformedBody(body: String) async {
        StubURLProtocol.respond(status: 200, body: body)
        await #expect(throws: NutritionServiceError.decoding) {
            try await service.search("apple")
        }
    }

    @Test("Transport failures keep their URLError code", arguments: [
        URLError.Code.notConnectedToInternet, .timedOut, .cannotFindHost
    ])
    func transportFailure(code: URLError.Code) async {
        StubURLProtocol.handler = { _ in throw URLError(code) }
        await #expect(throws: NutritionServiceError.network(code)) {
            try await service.search("apple")
        }
    }

    @Test("Every error has a user-facing description")
    func errorDescriptions() {
        let errors: [NutritionServiceError] = [
            .emptyQuery, .unauthorized, .rateLimited, .http(status: 500), .invalidResponse, .decoding,
            .network(.notConnectedToInternet), .network(.timedOut), .network(.cannotFindHost)
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}

@Suite("OfflineNutritionService")
struct OfflineNutritionServiceTests {
    private let service = OfflineNutritionService(foods: [
        FoodItem(name: "egg", calories: 147),
        FoodItem(name: "toast", calories: 293),
        FoodItem(name: "white rice", calories: 130),
        FoodItem(name: "brown rice", calories: 112),
        FoodItem(name: "tomato", calories: 18),
        FoodItem(name: "strawberries", calories: 32)
    ])

    @Test("Queries are split into food terms without quantities or filler words", arguments: [
        ("banana", ["banana"]),
        ("2 eggs and toast", ["egg", "toast"]),
        ("a slice of toast, 3 tomatoes", ["toast", "tomato"]),
        ("  White Rice  ", ["white rice"]),
        ("1.5 cups of brown rice", ["brown rice"]),
        ("2", []),
        ("", [])
    ])
    func terms(query: String, expected: [String]) {
        #expect(OfflineNutritionService.terms(in: query) == expected)
    }

    @Test("Finds each food named in a compound query, in query order")
    func compoundQuery() async throws {
        let items = try await service.search("toast and 2 eggs")
        #expect(items.map(\.name) == ["toast", "egg"])
    }

    @Test("A partial name matches every food containing it")
    func partialMatch() async throws {
        #expect(try await service.search("rice").map(\.name) == ["white rice", "brown rice"])
    }

    @Test("Singular and plural forms match each other", arguments: [
        ("strawberry", "strawberries"), ("strawberries", "strawberries"),
        ("eggs", "egg"), ("tomatoes", "tomato")
    ])
    func pluralsMatch(query: String, expected: String) async throws {
        #expect(try await service.search(query).map(\.name) == [expected])
    }

    @Test("Matching ignores case and never returns the same food twice")
    func caseAndDuplicates() async throws {
        #expect(try await service.search("EGG, eggs and Egg").map(\.name) == ["egg"])
    }

    @Test("Unknown foods return an empty result rather than an error")
    func unknownFood() async throws {
        #expect(try await service.search("dragonfruit").isEmpty)
    }

    @Test("A query with no food terms is an empty query", arguments: ["", "   ", "2", "a cup of"])
    func emptyQuery(query: String) async {
        await #expect(throws: NutritionServiceError.emptyQuery) {
            try await service.search(query)
        }
    }

    @Test("The bundled sample database loads and is well-formed")
    func bundledDatabase() throws {
        let bundled = try OfflineNutritionService(bundle: .main)
        #expect(bundled.foods.count >= 30)
        #expect(Set(bundled.foods.map(\.name)).count == bundled.foods.count, "food names must be unique")
        for food in bundled.foods {
            #expect(food.calories > 0, "\(food.name) has no calories")
            #expect(food.servingSizeG == 100, "\(food.name) is not per 100 g")
            #expect(food.name == food.name.lowercased(), "\(food.name) should be lowercase")
        }
    }

    @Test("The failing service always throws its configured error")
    func failingService() async {
        await #expect(throws: NutritionServiceError.rateLimited) {
            try await FailingNutritionService(error: .rateLimited).search("apple")
        }
    }
}
