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
                dismissesKeyboardOnAppear: true
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
                dismissesKeyboardOnAppear: true
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
                dismissesKeyboardOnAppear: true
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
                dismissesKeyboardOnAppear: true
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
                dismissesKeyboardOnAppear: true
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
                dismissesKeyboardOnAppear: true
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
                dismissesKeyboardOnAppear: true
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
                dismissesKeyboardOnAppear: true
            )
        }
    }
}
