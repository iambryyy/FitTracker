//
//  OnboardingView.swift
//  FitTracker
//

import SwiftUI

/// First-run screen: collects the profile that every calorie target is based on.
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profileStore
    @State private var draft = ProfileDraft()
    @State private var errors: [ProfileValidationError] = []

    var body: some View {
        // The stack exists to host the form's keyboard toolbar; it shows no bar.
        NavigationStack {
            form
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to FitTracker")
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier(AccessibilityID.Onboarding.title)
                        .accessibilityAddTraits(.isHeader)
                    Text("Tell us a little about yourself and we'll work out a daily calorie goal for you.")
                        .foregroundStyle(.secondary)
                }

                ProfileFormFields(draft: $draft)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                ProfileFormStatus(draft: draft, errors: errors)
                Button("Get Started", action: submit)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Onboarding.submitButton)
            }
            .padding(16)
            .background(.bar)
        }
        .onChange(of: draft) {
            // Clear stale messages as soon as the user starts fixing them.
            if !errors.isEmpty { errors = [] }
        }
    }

    private func submit() {
        switch draft.validate() {
        case .success(let profile):
            errors = []
            profileStore.save(profile)
        case .failure(let failure):
            errors = failure.errors
        }
    }
}

#Preview {
    OnboardingView()
        .environment(ProfileStore(storage: InMemoryKeyValueStore()))
}
