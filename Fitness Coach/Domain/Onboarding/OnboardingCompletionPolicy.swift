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
        case journey
        case plan
    }

    static func initialMainTab(persistedTabRawValue: String?) -> MainTabDestination {
        guard let raw = persistedTabRawValue else { return .today }
        switch raw {
        case "training", "progress":
            return .journey
        case "profile":
            return .plan
        default:
            return MainTabDestination(rawValue: raw) ?? .today
        }
    }
}
