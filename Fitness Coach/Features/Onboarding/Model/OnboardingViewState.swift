//
//  OnboardingViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Screen-level state for Onboarding.
//

import Foundation

enum OnboardingViewState: Equatable {
    case editing
    case generatingPlan
    case completing
    case error(String)
}
