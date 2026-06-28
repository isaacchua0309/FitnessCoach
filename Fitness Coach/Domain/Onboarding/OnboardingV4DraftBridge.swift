//
//  OnboardingV4DraftBridge.swift
//  Fitness Coach
//
//  Forma — Maps v4 steps to legacy OnboardingStep for draft persistence (schema unchanged).
//

import Foundation

enum OnboardingV4DraftBridge {

    /// Legacy step written to `OnboardingDraft.currentStepRawValue` while v4 is active.
    static func persistedLegacyStep(for v4Step: OnboardingV4Step) -> OnboardingStep {
        persistedLegacyStep(for: v4Step, formState: OnboardingFormState())
    }

    /// Legacy step written to `OnboardingDraft.currentStepRawValue` while v4 is active.
    static func persistedLegacyStep(
        for v4Step: OnboardingV4Step,
        formState: OnboardingFormState
    ) -> OnboardingStep {
        switch v4Step {
        case .introProof:
            return .landing
        case .heightWeight, .birthday:
            return .body
        case .targetWeight, .targetEncouragement:
            return .goal
        case .activityLevel, .appleHealth:
            return .activity
        case .almostThere, .formaProof, .review:
            return .summary
        case .generatingPlan:
            return .generatingPlan
        case .planReveal:
            return .planReveal
        case .savePlan:
            return .savePlan
        }
    }

    /// Resolves the v4 step to show when restoring a draft saved with a legacy step id.
    static func restoredV4Step(
        legacyStep: OnboardingStep,
        formState: OnboardingFormState,
        flow: [OnboardingV4Step]
    ) -> OnboardingV4Step {
        switch legacyStep {
        case .landing, .welcome:
            return flow.contains(.introProof) ? .introProof : (flow.first ?? .introProof)
        case .motivation, .preferences:
            return firstIncompleteDataStep(in: flow, formState: formState) ?? .review
        case .body:
            return firstIncompleteBodyStep(formState: formState, flow: flow)
        case .goal:
            if flow.contains(.targetWeight), formState.validationMessageV4(for: .targetWeight) != nil {
                return .targetWeight
            }
            if flow.contains(.targetEncouragement) {
                return .targetEncouragement
            }
            return flow.contains(.targetWeight) ? .targetWeight : .review
        case .activity:
            return flow.contains(.activityLevel) ? .activityLevel : .review
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

    /// Analytics step slug for v4 events.
    static func analyticsStepName(_ step: OnboardingV4Step) -> String {
        switch step {
        case .introProof: return "introProof"
        case .heightWeight: return "heightWeight"
        case .targetWeight: return "targetWeight"
        case .targetEncouragement: return "targetEncouragement"
        case .birthday: return "birthday"
        case .activityLevel: return "activityLevel"
        case .appleHealth: return "appleHealth"
        case .almostThere: return "almostThere"
        case .formaProof: return "formaProof"
        case .review: return "review"
        case .generatingPlan: return "generatingPlan"
        case .planReveal: return "planReveal"
        case .savePlan: return "savePlan"
        }
    }

    private static func firstIncompleteBodyStep(
        formState: OnboardingFormState,
        flow: [OnboardingV4Step]
    ) -> OnboardingV4Step {
        if flow.contains(.heightWeight), formState.validationMessageV4(for: .heightWeight) != nil {
            return .heightWeight
        }
        if flow.contains(.birthday), formState.validationMessageV4(for: .birthday) != nil {
            return .birthday
        }
        if flow.contains(.birthday) {
            return .birthday
        }
        return flow.first { $0.stage == .body } ?? .heightWeight
    }

    private static func firstIncompleteDataStep(
        in flow: [OnboardingV4Step],
        formState: OnboardingFormState
    ) -> OnboardingV4Step? {
        if flow.contains(.heightWeight) {
            return .heightWeight
        }
        return flow.first
    }
}
