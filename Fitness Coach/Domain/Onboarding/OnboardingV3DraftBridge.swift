//
//  OnboardingV3DraftBridge.swift
//  Fitness Coach
//
//  Forma — Maps v3 steps to legacy OnboardingStep for draft persistence (schema unchanged).
//

import Foundation

enum OnboardingV3DraftBridge {

    /// Legacy step written to `OnboardingDraft.currentStepRawValue` while v3 is active.
    static func persistedLegacyStep(for v3Step: OnboardingV3Step) -> OnboardingStep {
        persistedLegacyStep(for: v3Step, formState: OnboardingFormState())
    }

    /// Legacy step written to `OnboardingDraft.currentStepRawValue` while v3 is active.
    static func persistedLegacyStep(
        for v3Step: OnboardingV3Step,
        formState: OnboardingFormState
    ) -> OnboardingStep {
        switch v3Step {
        case .landing:
            return .landing
        case .motivation:
            return .motivation
        case .bodyBasics, .age, .sex, .height, .currentWeight:
            return .body
        case .goalWeight, .pace, .customPace:
            return .goal
        case .activityLevel, .trainingRhythm:
            return .activity
        case .preferences, .preferenceDetails:
            return .preferences
        case .review:
            return .summary
        case .generatingPlan:
            return .generatingPlan
        case .planReveal:
            return .planReveal
        case .savePlan:
            return .savePlan
        }
    }

    /// Resolves the v3 step to show when restoring a draft saved with a legacy step id.
    static func restoredV3Step(
        legacyStep: OnboardingStep,
        formState: OnboardingFormState,
        flow: [OnboardingV3Step]
    ) -> OnboardingV3Step {
        switch legacyStep {
        case .landing:
            return .landing
        case .welcome:
            return flow.contains(.motivation) ? .motivation : .landing
        case .motivation:
            return .motivation
        case .body:
            return OnboardingV3Step.firstIncompleteBodyBasicsSubStep(for: formState)
                ?? .currentWeight
        case .goal:
            if formState.validationMessageV3(for: .goalWeight) != nil {
                return .goalWeight
            }
            if formState.isPaceApplicable(),
               formState.validationMessageV3(for: .pace) != nil {
                return .pace
            }
            return .goalWeight
        case .activity:
            if formState.validationMessageV3(for: .activityLevel) != nil {
                return .activityLevel
            }
            if formState.validationMessageV3(for: .trainingRhythm) != nil {
                return .trainingRhythm
            }
            return .activityLevel
        case .preferences:
            return .preferences
        case .summary:
            return .review
        case .generatingPlan:
            return .review
        case .planReveal, .planPreview:
            return .planReveal
        case .savePlan:
            return .savePlan
        }
    }

    /// Analytics step slug for v3 events.
    static func analyticsStepName(_ step: OnboardingV3Step) -> String {
        switch step {
        case .landing: return "landing"
        case .motivation: return "motivation"
        case .bodyBasics: return "bodyBasics"
        case .age: return "age"
        case .sex: return "sex"
        case .height: return "height"
        case .currentWeight: return "currentWeight"
        case .goalWeight: return "goalWeight"
        case .pace: return "pace"
        case .customPace: return "customPace"
        case .activityLevel: return "activityLevel"
        case .trainingRhythm: return "trainingRhythm"
        case .preferences: return "preferences"
        case .preferenceDetails: return "preferenceDetails"
        case .review: return "review"
        case .generatingPlan: return "generatingPlan"
        case .planReveal: return "planReveal"
        case .savePlan: return "savePlan"
        }
    }
}
