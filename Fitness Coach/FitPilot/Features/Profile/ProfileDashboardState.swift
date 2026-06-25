//
//  ProfileDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Read-focused state for the Profile screen.
//
//  View state only. No SwiftData entities and no persistence.
//

import Foundation

struct ProfileDashboardState: Equatable {
    var profile: UserProfile
    var profileSummary: ProfileSummary
    var targetSummary: TargetSummary
    var activitySummary: ActivitySummary
    var preferenceSummary: PreferenceSummary
}

struct ProfileSummary: Equatable {
    var nameText: String
    var ageText: String
    var sexText: String
    var heightText: String
    var currentWeightText: String
    var goalWeightText: String
    var bodyFatText: String?
}

struct TargetSummary: Equatable {
    var calorieTargetText: String
    var proteinTargetText: String
    var carbTargetText: String
    var fatTargetText: String
    var waterTargetText: String
    var aggressivenessText: String
    var expectedWeeklyLossText: String?
}

struct ActivitySummary: Equatable {
    var activityLevelText: String
    var trainingFrequencyText: String
    var averageStepsText: String
}

struct PreferenceSummary: Equatable {
    var dietPreferenceText: String
    var unitSystemText: String
}
