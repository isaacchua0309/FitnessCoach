//
//  OnboardingV3InteractionPolicy.swift
//  Fitness Coach
//
//  Forma — Per-screen interaction rules for tap-first onboarding v3.
//

import Foundation

/// Describes how a v3 step should behave before its dedicated UI exists.
struct OnboardingV3InteractionRules: Equatable, Sendable {
    /// Primary user-facing job for this screen (one question / one decision).
    let primaryJob: String
    /// Whether any required input on this step may use the keyboard.
    let allowsKeyboardForRequiredInput: Bool
    /// Whether optional free-text may appear without an explicit user action.
    let showsFreeTextByDefault: Bool
    /// Whether the user can continue without providing an answer.
    let isOptional: Bool
    /// Whether step-level validation runs when Continue is tapped.
    let validatesOnContinue: Bool
    /// Prefer fitting content without scroll at default Dynamic Type on iPhone 15-class devices.
    let prefersCompactLayout: Bool
    /// Whether the shared sticky Continue footer is shown (landing/save use local CTAs).
    let showsSharedBottomBar: Bool
    /// Whether the step should dismiss the keyboard when it appears.
    let dismissesKeyboardOnAppear: Bool
}

enum OnboardingV3InteractionPolicy {

    static func rules(for step: OnboardingV3Step) -> OnboardingV3InteractionRules {
        switch step {
        case .landing:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose to get started or sign in to an existing account",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: false,
                dismissesKeyboardOnAppear: true
            )
        case .motivation:
            return OnboardingV3InteractionRules(
                primaryJob: "Pick one or two reasons (optional)",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: true,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .bodyBasics:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose age, height, weight, and sex",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .age:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose your age",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .sex:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose sex for target estimation",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .height:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose your height",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .currentWeight:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose your current weight",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .goalWeight:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose your goal weight",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .pace:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose a weight-loss pace",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .customPace:
            return OnboardingV3InteractionRules(
                primaryJob: "Set a custom pace (optional advanced path)",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .activityLevel:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose one activity level",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .trainingRhythm:
            return OnboardingV3InteractionRules(
                primaryJob: "Choose training days and daily movement band",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: false,
                validatesOnContinue: true,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .preferences:
            return OnboardingV3InteractionRules(
                primaryJob: "Pick optional logging and diet chips",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: false,
                isOptional: true,
                validatesOnContinue: false,
                prefersCompactLayout: true,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: true
            )
        case .preferenceDetails:
            return OnboardingV3InteractionRules(
                primaryJob: "Add optional name or diet notes",
                allowsKeyboardForRequiredInput: false,
                showsFreeTextByDefault: true,
                isOptional: true,
                validatesOnContinue: false,
                prefersCompactLayout: false,
                showsSharedBottomBar: true,
                dismissesKeyboardOnAppear: false
            )
        case .review:
            return OnboardingV3InteractionRules(
                primaryJob: "Review decision-critical choices",
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
                primaryJob: "Wait while the plan is prepared",
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
                primaryJob: "Review starting targets",
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
                primaryJob: "Save plan and sign in when required",
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

    /// Preset pace choices surfaced on the pace screen (Advanced is behind disclosure).
    static let visiblePaceChoices: [WeightLossPaceChoice] = [.gentle, .moderate, .aggressive]

    static let customPaceDisclosureTitle = "Set custom pace"
    static let preferenceDetailsDisclosureTitle = "Add details"
}
