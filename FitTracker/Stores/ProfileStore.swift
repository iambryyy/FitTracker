//
//  ProfileStore.swift
//  FitTracker
//

import Foundation
import Observation

/// Holds the saved user profile. `profile` is `nil` until onboarding finishes.
@MainActor
@Observable
final class ProfileStore {
    static let storageKey = "fittracker.profile.v1"

    private(set) var profile: UserProfile?

    @ObservationIgnored private let storage: KeyValueStoring

    init(storage: KeyValueStoring) {
        self.storage = storage
        if let data = storage.data(forKey: Self.storageKey) {
            profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        }
    }

    func save(_ profile: UserProfile) {
        self.profile = profile
        storage.setData(try? JSONEncoder().encode(profile), forKey: Self.storageKey)
    }

    func clear() {
        profile = nil
        storage.setData(nil, forKey: Self.storageKey)
    }
}
