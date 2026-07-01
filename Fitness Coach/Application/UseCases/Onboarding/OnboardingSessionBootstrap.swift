//
//  OnboardingSessionBootstrap.swift
//  Fitness Coach
//
//  Resolves the initial onboarding step from drafts and committed profiles.
//

import Foundation

enum OnboardingSessionBootstrap {

    struct ResolvedSession {
        let initialStep: OnboardingStep
        let formState: OnboardingFormState
        let generatedPlan: CalorieTargetResult?
        let planRevealState: OnboardingPlanRevealState?
        let hasLocalProfile: Bool
        let hasCommittedLocalProfile: Bool
        let restoredFromDraft: Bool
    }

    @MainActor
    static func resolve(
        analyticsEntry: OnboardingAnalyticsEntry,
        draftStore: OnboardingDraftStore,
        userProfileReader: any UserProfileReading
    ) -> ResolvedSession {
        var formState = OnboardingFormState()
        var generatedPlan: CalorieTargetResult?
        var planRevealState: OnboardingPlanRevealState?
        var hasLocalProfile = false
        var hasCommittedLocalProfile = false
        var restoredFromDraft = false

        let initialStep: OnboardingStep
        if let draft = draftStore.loadDraft(), draft.step != nil {
            formState = draft.makeFormState()
            generatedPlan = draft.makeGeneratedPlan()
            if let restoredPlan = generatedPlan {
                planRevealState = OnboardingPlanRevealBuilder.build(
                    formState: formState,
                    plan: restoredPlan
                )
            }
            let restoredStep = OnboardingDraftStepResolver.restoredStep(
                rawValue: draft.step!.rawValue,
                formState: formState,
                flow: OnboardingStep.flow
            )
            hasLocalProfile = (try? userProfileReader.getCurrentProfile()) != nil
            if restoredStep == .savePlan, hasLocalProfile {
                hasCommittedLocalProfile = true
                draftStore.clearDraft()
            }
            restoredFromDraft = true
            initialStep = restoredStep
        } else if let profile = try? userProfileReader.getCurrentProfile() {
            hasLocalProfile = true
            if OnboardingCommittedProfileRestorer.shouldResumeSavePlan(profile: profile) {
                hasCommittedLocalProfile = true
                OnboardingCommittedProfileRestorer.hydrateFormState(&formState, from: profile)
                let plan = OnboardingCommittedProfileRestorer.reconstructGeneratedPlan(from: profile)
                generatedPlan = plan
                planRevealState = OnboardingPlanRevealBuilder.build(formState: formState, plan: plan)
                initialStep = .savePlan
            } else {
                initialStep = OnboardingEntry.initialStep(for: analyticsEntry)
            }
        } else {
            initialStep = OnboardingEntry.initialStep(for: analyticsEntry)
        }

        return ResolvedSession(
            initialStep: initialStep,
            formState: formState,
            generatedPlan: generatedPlan,
            planRevealState: planRevealState,
            hasLocalProfile: hasLocalProfile,
            hasCommittedLocalProfile: hasCommittedLocalProfile,
            restoredFromDraft: restoredFromDraft
        )
    }
}
