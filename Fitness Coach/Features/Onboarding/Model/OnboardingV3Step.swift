//
//  OnboardingV3Step.swift
//  Fitness Coach
//
//  Forma — Tap-first onboarding v3 step graph (one main job per screen).
//
//  Stage 1 defines structure and interaction rules. Individual picker screens
//  are wired incrementally in later stages; legacy step views may serve as
//  temporary placeholders until split.
//

import Foundation

/// Coarse journey phase for the v3 progress header.
enum OnboardingV3Stage: String, CaseIterable, Equatable, Sendable, Identifiable {
    case start
    case bodyBasics
    case destination
    case activity
    case preferences
    case plan
    case save

    var id: String { rawValue }

    var progressIndex: Int {
        switch self {
        case .start: return 1
        case .bodyBasics: return 2
        case .destination: return 3
        case .activity: return 4
        case .preferences: return 5
        case .plan: return 6
        case .save: return 7
        }
    }

    static var stageCount: Int { allCases.count }

    var progressAccessibilityLabel: String {
        "\(displayTitle), \(progressIndex) of \(Self.stageCount)"
    }

    var displayTitle: String {
        switch self {
        case .start:
            return "Getting started"
        case .bodyBasics:
            return "Your basics"
        case .destination:
            return "Your destination"
        case .activity:
            return "Activity & training"
        case .preferences:
            return "Preferences"
        case .plan:
            return "Your plan"
        case .save:
            return "Save your plan"
        }
    }
}

enum OnboardingV3Step: Int, Equatable, Identifiable, Sendable, CaseIterable {

    // Start
    case landing = 200
    case motivation = 201

    // Body basics — single compact picker-first screen (Stage 4)
    case bodyBasics = 209

    /// Legacy split sub-steps — retained for draft/analytics compatibility only.
    case age = 210
    case sex = 211
    case height = 212
    case currentWeight = 213

    // Destination
    case goalWeight = 220
    case pace = 221
  /// Shown only after the user taps “Set custom pace” on the pace screen.
    case customPace = 222

    // Activity & training rhythm
    case activityLevel = 230
    case trainingRhythm = 231

    // Preferences (optional chips; free-text behind disclosure)
    case preferences = 240
    case preferenceDetails = 241

    // Plan moments
    case review = 250
    case generatingPlan = 251
    case planReveal = 252
    case savePlan = 253

    var id: Int { rawValue }

    // MARK: - Flows

    /// Pre-auth full journey: landing through save plan.
    static let fullFlow: [OnboardingV3Step] = [
        .landing, .motivation,
        .bodyBasics,
        .goalWeight,
        .activityLevel, .trainingRhythm,
        .preferences,
        .review, .generatingPlan, .planReveal, .savePlan
    ]

    /// Value-first teaser ends after landing before sign-in handoff.
    static let valueFirstTeaserFlow: [OnboardingV3Step] = [.landing]

    /// Post-auth continuation (skips landing).
    static let postAuthFlow: [OnboardingV3Step] = [
        .motivation,
        .bodyBasics,
        .goalWeight,
        .activityLevel, .trainingRhythm,
        .preferences,
        .review, .generatingPlan, .planReveal, .savePlan
    ]

    static func flow(for scope: OnboardingFlowScope) -> [OnboardingV3Step] {
        switch scope {
        case .legacy:
            return []
        case .v2Full:
            return fullFlow
        case .v2ValueFirstTeaser:
            return valueFirstTeaserFlow
        case .v2PostAuth:
            return postAuthFlow
        }
    }

    static var entryStep: OnboardingV3Step {
        OnboardingV3FeatureFlag.isActive ? flowForActiveScope().first ?? .landing : .landing
    }

    static func flowForActiveScope(
        scope: OnboardingFlowScope = OnboardingFlowScope.resolve(
            routingMode: OnboardingV2FeatureFlag.routingMode,
            entry: .preAuth
        )
    ) -> [OnboardingV3Step] {
        flow(for: scope)
    }

    // MARK: - Stage mapping

    var stage: OnboardingV3Stage {
        switch self {
        case .landing, .motivation:
            return .start
        case .bodyBasics, .age, .sex, .height, .currentWeight:
            return .bodyBasics
        case .goalWeight, .pace, .customPace:
            return .destination
        case .activityLevel, .trainingRhythm:
            return .activity
        case .preferences, .preferenceDetails:
            return .preferences
        case .review, .generatingPlan, .planReveal:
            return .plan
        case .savePlan:
            return .save
        }
    }

    // MARK: - Copy

    var title: String {
        let copy = FormaProductCopy.Onboarding.V3.self
        switch self {
        case .landing:
            return FormaProductCopy.Onboarding.V2.Landing.title
        case .motivation:
            return FormaProductCopy.Onboarding.V2.Motivation.title
        case .bodyBasics:
            return FormaProductCopy.Onboarding.V2.Body.title
        case .age:
            return copy.Age.title
        case .sex:
            return copy.Sex.title
        case .height:
            return copy.Height.title
        case .currentWeight:
            return copy.CurrentWeight.title
        case .goalWeight:
            return copy.GoalWeight.title
        case .pace:
            return copy.Pace.title
        case .customPace:
            return copy.CustomPace.title
        case .activityLevel:
            return FormaProductCopy.Onboarding.V2.Activity.title
        case .trainingRhythm:
            return copy.TrainingRhythm.title
        case .preferences:
            return FormaProductCopy.Onboarding.V2.Preferences.title
        case .preferenceDetails:
            return copy.PreferenceDetails.title
        case .review:
            return copy.Review.title
        case .generatingPlan:
            return FormaProductCopy.Onboarding.V2.Generating.title
        case .planReveal:
            return FormaProductCopy.Onboarding.V2.PlanReveal.title
        case .savePlan:
            return FormaProductCopy.Onboarding.V2.SavePlan.title
        }
    }

    var subtitle: String {
        let copy = FormaProductCopy.Onboarding.V3.self
        switch self {
        case .landing:
            return FormaProductCopy.Onboarding.V2.Landing.subtitle
        case .motivation:
            return FormaProductCopy.Onboarding.V2.Motivation.subtitle
        case .bodyBasics:
            return FormaProductCopy.Onboarding.V2.Body.subtitle
        case .age:
            return copy.Age.subtitle
        case .sex:
            return copy.Sex.subtitle
        case .height:
            return copy.Height.subtitle
        case .currentWeight:
            return copy.CurrentWeight.subtitle
        case .goalWeight:
            return copy.GoalWeight.subtitle
        case .pace:
            return copy.Pace.subtitle
        case .customPace:
            return copy.CustomPace.subtitle
        case .activityLevel:
            return FormaProductCopy.Onboarding.V2.Activity.subtitle
        case .trainingRhythm:
            return copy.TrainingRhythm.subtitle
        case .preferences:
            return copy.Preferences.subtitle
        case .preferenceDetails:
            return copy.PreferenceDetails.subtitle
        case .review:
            return copy.Review.subtitle
        case .generatingPlan:
            return FormaProductCopy.Loading.generatingPlan
        case .planReveal:
            return FormaProductCopy.Onboarding.V2.PlanReveal.subtitle
        case .savePlan:
            return FormaProductCopy.Onboarding.V2.SavePlan.subtitle
        }
    }

    // MARK: - Navigation

    func next(
        in flow: [OnboardingV3Step],
        formState: OnboardingFormState,
        session: OnboardingV3UISessionState
    ) -> OnboardingV3Step? {
        guard let index = flow.firstIndex(of: self) else { return nil }

        var cursor = index + 1
        while cursor < flow.count {
            let candidate = flow[cursor]
            if shouldIncludeInFlow(candidate, formState: formState, session: session) {
                return candidate
            }
            cursor += 1
        }
        return nil
    }

    func previous(
        in flow: [OnboardingV3Step],
        formState: OnboardingFormState,
        session: OnboardingV3UISessionState
    ) -> OnboardingV3Step? {
        guard let index = flow.firstIndex(of: self), index > 0 else { return nil }

        var cursor = index - 1
        while cursor >= 0 {
            let candidate = flow[cursor]
            if shouldIncludeInFlow(candidate, formState: formState, session: session) {
                return candidate
            }
            cursor -= 1
        }
        return nil
    }

    func allowsBackNavigation(in flow: [OnboardingV3Step]) -> Bool {
        switch self {
        case .generatingPlan, .landing:
            return false
        default:
            guard let index = flow.firstIndex(of: self) else { return false }
            return index > 0
        }
    }

    func allowsBackNavigation(
        in flow: [OnboardingV3Step],
        formState: OnboardingFormState,
        session: OnboardingV3UISessionState
    ) -> Bool {
        switch self {
        case .generatingPlan, .landing:
            return false
        default:
            return previous(in: flow, formState: formState, session: session) != nil
        }
    }

    func backTarget(
        in flow: [OnboardingV3Step],
        formState: OnboardingFormState,
        session: OnboardingV3UISessionState
    ) -> OnboardingV3Step? {
        guard allowsBackNavigation(in: flow, formState: formState, session: session) else {
            return nil
        }

        switch self {
        case .planReveal:
            return .review
        case .savePlan:
            return .planReveal
        case .customPace:
            return .pace
        case .preferenceDetails:
            return .preferences
        default:
            return previous(in: flow, formState: formState, session: session)
        }
    }

    var usesFullScreenChrome: Bool {
        switch self {
        case .generatingPlan, .landing:
            return true
        default:
            return false
        }
    }

    var showsProgressHeader: Bool {
        switch self {
        case .landing, .generatingPlan:
            return false
        default:
            return true
        }
    }

    func clearsGeneratedPlanWhenNavigatingBack(in flow: [OnboardingV3Step]) -> Bool {
        self == .planReveal && flow.contains(.planReveal)
    }

    /// Whether this step should appear in the linear flow for the current answers.
    func shouldIncludeInFlow(
        _ step: OnboardingV3Step,
        formState: OnboardingFormState,
        session: OnboardingV3UISessionState
    ) -> Bool {
        switch step {
        case .pace:
            return formState.isPaceApplicable()
        case .customPace:
            return formState.isPaceApplicable() && session.showsCustomPace
        case .preferenceDetails:
            return session.showsPreferenceDetails
        default:
            return true
        }
    }

    /// Body-basics sub-steps in display order (legacy split flow).
    static let bodyBasicsSubSteps: [OnboardingV3Step] = [.age, .sex, .height, .currentWeight]

    /// First incomplete body-basics step, or `nil` when satisfied.
    static func firstIncompleteBodyBasicsSubStep(for formState: OnboardingFormState) -> OnboardingV3Step? {
        formState.canAdvanceV3(from: .bodyBasics) ? nil : .bodyBasics
    }
}

// MARK: - Flow policy

enum OnboardingV3StepPolicy {

    static var isActive: Bool { OnboardingV3FeatureFlag.isActive }

    static func flow(for scope: OnboardingFlowScope) -> [OnboardingV3Step] {
        OnboardingV3Step.flow(for: scope)
    }

    static func entryStep(for scope: OnboardingFlowScope) -> OnboardingV3Step {
        scope.usesV3Steps ? (OnboardingV3Step.flow(for: scope).first ?? .landing) : .landing
    }

    static func next(
        after step: OnboardingV3Step,
        in flow: [OnboardingV3Step],
        formState: OnboardingFormState,
        session: OnboardingV3UISessionState
    ) -> OnboardingV3Step? {
        step.next(in: flow, formState: formState, session: session)
    }

    static func back(
        from step: OnboardingV3Step,
        in flow: [OnboardingV3Step],
        formState: OnboardingFormState,
        session: OnboardingV3UISessionState
    ) -> OnboardingV3Step? {
        step.backTarget(in: flow, formState: formState, session: session)
    }
}
