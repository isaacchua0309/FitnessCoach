//
//  OnboardingDraftStepResolver.swift
//  Fitness Coach
//
//  Forma — Resolves saved draft step ids to wizard steps (canonical + legacy migration).
//

import Foundation

enum OnboardingDraftStepResolver {

    static func restoredStep(
        rawValue: Int,
        formState: OnboardingFormState,
        flow: [OnboardingStep]
    ) -> OnboardingStep {
        if let canonical = OnboardingStep(rawValue: rawValue) {
            return normalizeCanonicalStep(canonical, formState: formState, flow: flow)
        }
        if let legacy = OnboardingLegacyPersistedStep(rawValue: rawValue) {
            return restoredStep(fromLegacy: legacy, formState: formState, flow: flow)
        }
        return flow.first ?? .introProof
    }

    // MARK: - Canonical

    private static func normalizeCanonicalStep(
        _ step: OnboardingStep,
        formState: OnboardingFormState,
        flow: [OnboardingStep]
    ) -> OnboardingStep {
        switch step {
        case .generatingPlan:
            return .review
        default:
            break
        }

        if flow.contains(step) {
            return step
        }

        return nearestRequiredStep(formState: formState, flow: flow)
            ?? flow.first
            ?? .introProof
    }

    // MARK: - Legacy migration

    private static func restoredStep(
        fromLegacy legacy: OnboardingLegacyPersistedStep,
        formState: OnboardingFormState,
        flow: [OnboardingStep]
    ) -> OnboardingStep {
        switch legacy {
        case .welcome, .landing:
            return flow.contains(.introProof) ? .introProof : (flow.first ?? .introProof)
        case .body:
            return restoredBodyStep(formState: formState, flow: flow)
        case .goal:
            return restoredGoalStep(formState: formState, flow: flow)
        case .activity:
            return flow.contains(.activityLevel) ? .activityLevel : restoredReviewOrRequired(formState: formState, flow: flow)
        case .preferences, .motivation, .summary:
            return restoredReviewOrRequired(formState: formState, flow: flow)
        case .generatingPlan:
            return .review
        case .planReveal, .planPreview:
            return .planReveal
        case .savePlan:
            return .savePlan
        }
    }

    private static func restoredBodyStep(
        formState: OnboardingFormState,
        flow: [OnboardingStep]
    ) -> OnboardingStep {
        if flow.contains(.heightWeight), formState.validationMessage(for: .heightWeight) != nil {
            return .heightWeight
        }
        if flow.contains(.birthday), formState.validationMessage(for: .birthday) != nil {
            return .birthday
        }
        return stepAfterBodyStage(in: flow) ?? .heightWeight
    }

    private static func restoredGoalStep(
        formState: OnboardingFormState,
        flow: [OnboardingStep]
    ) -> OnboardingStep {
        if flow.contains(.targetWeight), formState.validationMessage(for: .targetWeight) != nil {
            return .targetWeight
        }
        if flow.contains(.targetEncouragement) {
            return .targetEncouragement
        }
        return stepAfterGoalStage(in: flow) ?? restoredReviewOrRequired(formState: formState, flow: flow)
    }

    private static func restoredReviewOrRequired(
        formState: OnboardingFormState,
        flow: [OnboardingStep]
    ) -> OnboardingStep {
        if OnboardingFormState.firstInvalidRequiredStep(for: formState) == nil,
           flow.contains(.review) {
            return .review
        }
        return nearestRequiredStep(formState: formState, flow: flow)
            ?? flow.first
            ?? .introProof
    }

    private static func nearestRequiredStep(
        formState: OnboardingFormState,
        flow: [OnboardingStep]
    ) -> OnboardingStep? {
        guard let required = OnboardingFormState.firstInvalidRequiredStep(for: formState) else {
            return nil
        }
        return flow.contains(required) ? required : nil
    }

    private static func stepAfterBodyStage(in flow: [OnboardingStep]) -> OnboardingStep? {
        if let birthdayIndex = flow.firstIndex(of: .birthday) {
            let nextIndex = birthdayIndex + 1
            if nextIndex < flow.count {
                return flow[nextIndex]
            }
        }
        if let heightWeightIndex = flow.firstIndex(of: .heightWeight) {
            let nextIndex = heightWeightIndex + 1
            if nextIndex < flow.count {
                return flow[nextIndex]
            }
        }
        return nil
    }

    private static func stepAfterGoalStage(in flow: [OnboardingStep]) -> OnboardingStep? {
        if let encouragementIndex = flow.firstIndex(of: .targetEncouragement) {
            let nextIndex = encouragementIndex + 1
            if nextIndex < flow.count {
                return flow[nextIndex]
            }
        }
        if let targetIndex = flow.firstIndex(of: .targetWeight) {
            let nextIndex = targetIndex + 1
            if nextIndex < flow.count {
                return flow[nextIndex]
            }
        }
        return nil
    }
}

/// Legacy draft step ids (schema v1). Decode-only — new drafts store `OnboardingStep` raw values.
enum OnboardingLegacyPersistedStep: Int, Equatable, Sendable {
    case welcome = 0
    case body = 1
    case goal = 2
    case activity = 3
    case preferences = 4
    case planPreview = 5

    case landing = 10
    case motivation = 11
    case summary = 12
    case generatingPlan = 13
    case planReveal = 14
    case savePlan = 15
}
