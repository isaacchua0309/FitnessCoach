//
//  OnboardingAnalyticsStepSlug.swift
//  Fitness Coach
//
//  Forma — Stable snake_case analytics slugs for onboarding steps.
//

import Foundation

enum OnboardingAnalyticsStepSlug: String, CaseIterable, Equatable, Sendable {
    case introProof = "intro_proof"
    case heightWeight = "height_weight"
    case targetWeight = "target_weight"
    case targetEncouragement = "target_encouragement"
    case birthday = "birthday"
    case activityLevel = "activity_level"
    case appleHealth = "apple_health"
    case almostThere = "almost_there"
    case formaProof = "forma_proof"
    case review = "review"
    case generatingPlan = "generating_plan"
    case planReveal = "plan_reveal"
    case savePlan = "save_plan"

    init(step: OnboardingStep) {
        switch step {
        case .introProof: self = .introProof
        case .heightWeight: self = .heightWeight
        case .targetWeight: self = .targetWeight
        case .targetEncouragement: self = .targetEncouragement
        case .birthday: self = .birthday
        case .activityLevel: self = .activityLevel
        case .appleHealth: self = .appleHealth
        case .almostThere: self = .almostThere
        case .formaProof: self = .formaProof
        case .review: self = .review
        case .generatingPlan: self = .generatingPlan
        case .planReveal: self = .planReveal
        case .savePlan: self = .savePlan
        }
    }

    var step: OnboardingStep {
        switch self {
        case .introProof: return .introProof
        case .heightWeight: return .heightWeight
        case .targetWeight: return .targetWeight
        case .targetEncouragement: return .targetEncouragement
        case .birthday: return .birthday
        case .activityLevel: return .activityLevel
        case .appleHealth: return .appleHealth
        case .almostThere: return .almostThere
        case .formaProof: return .formaProof
        case .review: return .review
        case .generatingPlan: return .generatingPlan
        case .planReveal: return .planReveal
        case .savePlan: return .savePlan
        }
    }
}
