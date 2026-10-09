//
//  FitTrackerApp.swift
//  FitTracker
//
//  Created by Cris Briseno on 12/3/23.
//
// Description: This is where all the pages should be linked together.


import SwiftUI
import UIKit

@main
struct FitTrackerApp: App {
    @State private var environment: AppEnvironment

    init() {
        let configuration = LaunchConfiguration.current
        if configuration.isUITesting {
            // Animations only add waiting time and flakiness under UI test.
            UIView.setAnimationsEnabled(false)
        }
        _environment = State(initialValue: AppEnvironment.make(configuration: configuration))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.profileStore)
                .environment(environment.diaryStore)
                .environment(\.nutritionService, environment.nutritionService)
                .environment(\.searchSource, environment.searchSource)
                .tint(.ftTeal)
        }
    }
}
