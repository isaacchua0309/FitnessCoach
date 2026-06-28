//
//  OnboardingCoachingContext.swift
//  Fitness Coach
//
//  Forma — Optional coaching context captured during onboarding.
//  Stored separately from UserProfile (UserDefaults) until cloud schema extends.
//

import Foundation

struct OnboardingCoachingContext: Codable, Equatable, Sendable {

    static let currentOnboardingVersion = 4
    static let userDefaultsKey = "forma.onboarding.coachingContext"

    var motivations: [String]
    var loggingPreferences: [String]
    var capturedAt: Date
    var onboardingVersion: Int

    init(
        motivations: [String],
        loggingPreferences: [String],
        capturedAt: Date,
        onboardingVersion: Int
    ) {
        self.motivations = motivations
        self.loggingPreferences = loggingPreferences
        self.capturedAt = capturedAt
        self.onboardingVersion = onboardingVersion
    }

    init(
        selectedMotivations: Set<OnboardingMotivation>,
        selectedLoggingPreferences: Set<OnboardingLoggingPreference>,
        capturedAt: Date = Date(),
        onboardingVersion: Int = Self.currentOnboardingVersion
    ) {
        motivations = selectedMotivations.map(\.rawValue).sorted()
        loggingPreferences = selectedLoggingPreferences.map(\.rawValue).sorted()
        self.capturedAt = capturedAt
        self.onboardingVersion = onboardingVersion
    }

    var motivationSet: Set<OnboardingMotivation> {
        OnboardingMotivation.fromStoredValues(motivations)
    }

    var loggingPreferenceSet: Set<OnboardingLoggingPreference> {
        OnboardingLoggingPreference.fromStoredValues(loggingPreferences)
    }

    var isEmpty: Bool {
        motivations.isEmpty && loggingPreferences.isEmpty
    }
}
