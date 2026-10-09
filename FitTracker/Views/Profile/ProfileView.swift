//
//  ProfileView.swift
//  FitTracker
//

import SwiftUI

/// Lets the user edit their profile or wipe everything and start over.
struct ProfileView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(DiaryStore.self) private var diaryStore

    @State private var draft = ProfileDraft()
    @State private var errors: [ProfileValidationError] = []
    @State private var didSave = false
    @State private var isConfirmingReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProfileFormFields(draft: $draft)

                    ProfileFormStatus(draft: draft, errors: errors)

                    if didSave {
                        Label("Profile saved", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.ftTeal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier(AccessibilityID.Profile.savedConfirmation)
                    }

                    Button("Save Changes", action: save)
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier(AccessibilityID.Profile.saveButton)

                    Button("Reset All Data", role: .destructive) {
                        isConfirmingReset = true
                    }
                    .padding(.top, 8)
                    .accessibilityIdentifier(AccessibilityID.Profile.resetButton)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .confirmationDialog(
                "Delete your profile and every diary entry?",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    diaryStore.removeAll()
                    profileStore.clear()
                }
                .accessibilityIdentifier(AccessibilityID.Profile.confirmResetButton)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
        .onAppear(perform: loadDraft)
        .onChange(of: draft) {
            if !errors.isEmpty { errors = [] }
            didSave = false
        }
    }

    private func loadDraft() {
        if let profile = profileStore.profile {
            draft = ProfileDraft(profile: profile)
        }
    }

    private func save() {
        // Drop the keyboard so the result (and the tab bar) is visible.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        switch draft.validate() {
        case .success(let profile):
            profileStore.save(profile)
            errors = []
            didSave = true
        case .failure(let failure):
            errors = failure.errors
            didSave = false
        }
    }
}

#Preview {
    let storage = InMemoryKeyValueStore()
    let profileStore = ProfileStore(storage: storage)
    profileStore.save(.sample())
    return ProfileView()
        .environment(profileStore)
        .environment(DiaryStore(storage: storage))
}
