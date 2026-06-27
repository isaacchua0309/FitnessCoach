//
//  OnboardingLoggingStyleChoice.swift
//  Fitness Coach
//
//  Forma — Compact logging style choices for tap-first preferences onboarding.
//

import Foundation

enum OnboardingLoggingStyleChoice: String, CaseIterable, Equatable, Identifiable, Sendable {
    case chatWithCoach
    case quickTaps
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chatWithCoach:
            return "Chat with Coach"
        case .quickTaps:
            return "Quick taps"
        case .both:
            return "Both"
        }
    }

    var loggingPreferences: Set<OnboardingLoggingPreference> {
        switch self {
        case .chatWithCoach:
            return [.naturalLanguage]
        case .quickTaps:
            return [.quickTaps]
        case .both:
            return [.naturalLanguage, .quickTaps]
        }
    }

    static func inferred(from preferences: Set<OnboardingLoggingPreference>) -> OnboardingLoggingStyleChoice? {
        let relevant = preferences.intersection([.naturalLanguage, .quickTaps])
        guard !relevant.isEmpty else { return nil }

        if relevant.contains(.naturalLanguage), relevant.contains(.quickTaps) {
            return .both
        }
        if relevant.contains(.naturalLanguage) {
            return .chatWithCoach
        }
        if relevant.contains(.quickTaps) {
            return .quickTaps
        }
        return nil
    }
}

extension OnboardingFormState {

    var loggingStyleChoice: OnboardingLoggingStyleChoice? {
        OnboardingLoggingStyleChoice.inferred(from: loggingPreferences)
    }

    mutating func selectLoggingStyle(_ choice: OnboardingLoggingStyleChoice?) {
        guard let choice else {
            loggingPreferences = []
            return
        }
        loggingPreferences = choice.loggingPreferences
    }
}
