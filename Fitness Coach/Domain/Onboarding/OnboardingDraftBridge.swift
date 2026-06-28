//
//  OnboardingDraftBridge.swift
//  Fitness Coach
//
//  Forma — Onboarding analytics step naming (draft persistence uses OnboardingStep raw values).
//

import Foundation

enum OnboardingDraftBridge {

    static func analyticsStepName(_ step: OnboardingStep) -> String {
        OnboardingAnalyticsStepSlug(step: step).rawValue
    }
}
