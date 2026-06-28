//
//  OnboardingV4InteractionPolicy.swift
//  Fitness Coach
//
//  Forma — Per-screen interaction rules for onboarding v4 (navigation skeleton).
//

import Foundation

enum OnboardingV4InteractionPolicy {

    static func rules(for step: OnboardingV4Step) -> OnboardingV3InteractionRules {
        switch step {
        case .introProof:
            return OnboardingV3InteractionRules(
                primaryJob: "View intro and continue",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: false,
                dismissesKeyboardOnAppear: true
            )
        case .heightWeight, .targetWeight, .birthday:
            return OnboardingV3InteractionRules(
                primaryJob: step.title,
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .targetEncouragement, .appleHealth, .almostThere, .formaProof:
            return OnboardingV3InteractionRules(
                primaryJob: step.title,
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: true,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .activityLevel:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose activity level",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .review:
            return OnboardingV3InteractionRules(
                primaryJob: "Review and generate plan",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .generatingPlan:
            return OnboardingV3InteractionRules(
                primaryJob: "Wait for plan generation",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: false,
                dismissesKeyboardOnAppear: true
            )
        case .planReveal:
            return OnboardingV3InteractionRules(
                primaryJob: "Review generated plan",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .savePlan:
            return OnboardingV3InteractionRules(
                primaryJob: "Save plan",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: false,
                dismissesKeyboardOnAppear: true
            )
        }
    }
}
