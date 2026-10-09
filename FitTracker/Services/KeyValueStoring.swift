//
//  KeyValueStoring.swift
//  FitTracker
//

import Foundation

/// The slice of `UserDefaults` the stores depend on, so tests can swap in an
/// in-memory implementation.
protocol KeyValueStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
}

extension UserDefaults: KeyValueStoring {
    func setData(_ data: Data?, forKey key: String) {
        if let data {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

final class InMemoryKeyValueStore: KeyValueStoring {
    private var values: [String: Data]

    init(_ values: [String: Data] = [:]) {
        self.values = values
    }

    func data(forKey key: String) -> Data? { values[key] }

    func setData(_ data: Data?, forKey key: String) { values[key] = data }
}
