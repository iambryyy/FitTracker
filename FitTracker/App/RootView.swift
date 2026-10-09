//
//  RootView.swift
//  FitTracker
//

import SwiftUI

/// Shows onboarding until a profile exists, then the main tabs.
struct RootView: View {
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        if profileStore.profile == nil {
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "flame.fill") }
                .accessibilityIdentifier(AccessibilityID.Tab.today)

            DiaryView()
                .tabItem { Label("Diary", systemImage: "book.fill") }
                .accessibilityIdentifier(AccessibilityID.Tab.diary)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .accessibilityIdentifier(AccessibilityID.Tab.profile)
        }
    }
}
