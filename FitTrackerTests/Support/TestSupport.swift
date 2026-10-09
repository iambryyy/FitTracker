//
//  TestSupport.swift
//  FitTrackerTests
//

import Foundation
@testable import FitTracker

// MARK: Fixed time

/// Tests never read the real clock or the machine's time zone.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 15 June 2025, 12:00 UTC.
    static let now = date(2025, 6, 15, hour: 12)

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }
}

// MARK: Fixtures

extension FoodItem {
    static let banana = FoodItem(
        name: "banana", calories: 89, servingSizeG: 100,
        fatTotalG: 0.3, proteinG: 1.1, carbohydratesTotalG: 22.8
    )
    static let chicken = FoodItem(
        name: "chicken breast", calories: 165, servingSizeG: 100,
        fatTotalG: 3.6, proteinG: 31, carbohydratesTotalG: 0
    )
}

extension UserProfile {
    /// 30-year-old, 180 cm, 80 kg, moderately active male maintaining weight
    /// on `TestClock.now`. BMR 1780, TDEE 2759.
    static let reference = UserProfile(
        name: "Alex",
        sex: .male,
        birthDate: TestClock.date(1995, 6, 15),
        heightCm: 180,
        weightKg: 80,
        activityLevel: .moderate,
        goal: .maintain,
        unitSystem: .metric
    )
}

func isClose(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.01) -> Bool {
    abs(lhs - rhs) <= tolerance
}

// MARK: Network stubbing

/// Intercepts every request made through a session built with `makeSession()`.
final class StubURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    static var handler: Handler?
    static var recordedRequests: [URLRequest] = []

    static func reset() {
        handler = nil
        recordedRequests = []
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Responds to every request with the given status code and body.
    static func respond(status: Int, body: String) {
        handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.recordedRequests.append(request)
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: Nutrition service doubles

/// Returns a canned result and records the queries it was asked for.
final class MockNutritionService: NutritionService, @unchecked Sendable {
    var result: Result<[FoodItem], Error>
    private(set) var queries: [String] = []

    init(result: Result<[FoodItem], Error> = .success([])) {
        self.result = result
    }

    func search(_ query: String) async throws -> [FoodItem] {
        queries.append(query)
        return try result.get()
    }
}

/// Holds every search open until the test decides which one finishes, and in
/// what order. Used to prove out-of-order responses are handled.
actor ControlledNutritionService: NutritionService {
    private var pending: [CheckedContinuation<[FoodItem], Error>] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func search(_ query: String) async throws -> [FoodItem] {
        try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            let ready = waiters.filter { $0.count <= pending.count }
            waiters.removeAll { $0.count <= pending.count }
            ready.forEach { $0.continuation.resume() }
        }
    }

    /// Suspends until at least `count` searches have started.
    func waitForSearches(_ count: Int) async {
        guard pending.count < count else { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func finish(search index: Int, with items: [FoodItem]) {
        pending[index].resume(returning: items)
    }
}
