//
//  OnboardingInteractionPolicy.swift
//  Fitness Coach
//
//  Forma — Per-screen interaction rules for onboarding.
//

import Foundation

struct OnboardingInteractionRules: Equatable, Sendable {
    let primaryJob: String
    let allowsKeyboardForRequiredInput: Bool
    let showsFreeTextByDefault: Bool
    let isOptional: Bool
    let validatesOnContinue: Bool
    let prefersCompactLayout: Bool
    let showsSharedBottomBar: Bool
    let dismissesKeyboardOnAppear: Bool
    let reservesPlanRevealFooterSpace: Bool
}

enum OnboardingInteractionPolicy {

    static func rules(for step: OnboardingStep) -> OnboardingInteractionRules {
        switch step {
        case .introProof:
            return OnboardingInteractionRules(
                primaryJob: "View intro and continue",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true,
                reservesPlanRevealFooterSpace: false
            )
        case .heightWeight, .targetWeight, .birthday:
            return OnboardingInteractionRules(
                primaryJob: step.title,
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true,
                reservesPlanRevealFooterSpace: false
            )
        case .activityLevel:
            return OnboardingInteractionRules(
                primaryJob: "Choose activity level",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: false,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true,
                reservesPlanRevealFooterSpace: false
            )
        case .targetEncouragement, .appleHealth, .almostThere, .formaProof:
            return OnboardingInteractionRules(
                primaryJob: step.title,
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: true,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true,
                reservesPlanRevealFooterSpace: false
            )
        case .review:
            return OnboardingInteractionRules(
                primaryJob: "Review and generate plan",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true,
                reservesPlanRevealFooterSpace: false
            )
        case .generatingPlan:
            return OnboardingInteractionRules(
                primaryJob: "Wait for plan generation",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: false,
                dismissesKeyboardOnAppear: true,
                reservesPlanRevealFooterSpace: true
            )
        case .planReveal:
            return OnboardingInteractionRules(
                primaryJob: "Review generated plan",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true,
                reservesPlanRevealFooterSpace: false
            )
        case .savePlan:
            return OnboardingInteractionRules(
                primaryJob: "Save plan",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: false,
                dismissesKeyboardOnAppear: true,
                reservesPlanRevealFooterSpace: false
            )
        }
    }
}
