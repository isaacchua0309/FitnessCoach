//
//  OnboardingCompletionPolicy.swift
//  Fitness Coach
//
//  Forma — Post-onboarding main tab routing.
//

import Foundation

enum OnboardingCompletionPolicy {

    enum MainTabDestination: String, Equatable, Sendable {
        case today
        case coach
        case progress
        case profile
    }

    static func initialMainTab(persistedTabRawValue: String?) -> MainTabDestination {
        guard let persistedTabRawValue,
              let destination = MainTabDestination(rawValue: persistedTabRawValue) else {
            return .today
        }
        return destination
    }
}
