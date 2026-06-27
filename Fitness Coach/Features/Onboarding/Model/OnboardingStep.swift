//
//  OnboardingStep.swift
//  Fitness Coach
//
//  Forma — Onboarding wizard step definitions (v1 legacy + v2 flow).
//

import Foundation

enum OnboardingStep: Int, Equatable, Identifiable, Sendable {
    // Shared steps (stable raw values for draft persistence)
    case welcome = 0
    case body = 1
    case goal = 2
    case activity = 3
    case preferences = 4
    /// Legacy v1 terminal review step — same role as `planReveal` in v2.
    case planPreview = 5

    // V2-only steps
    case landing = 10
    case motivation = 11
    case summary = 12
    case generatingPlan = 13
    case planReveal = 14
    case savePlan = 15

    var id: Int { rawValue }

    // MARK: Flows

    static let legacyFlow: [OnboardingStep] = [
        .welcome, .body, .goal, .activity, .preferences, .planPreview
    ]

    static let v2Flow: [OnboardingStep] = [
        .landing, .welcome, .motivation, .body, .goal, .activity, .preferences,
        .summary, .generatingPlan, .planReveal, .savePlan
    ]

    /// Resolves persisted draft steps across onboarding versions.
    static func fromPersistedRawValue(_ rawValue: Int) -> OnboardingStep? {
        if let step = OnboardingStep(rawValue: rawValue) {
            return step
        }
        return nil
    }

    /// Terminal plan-review step for the active flow.
    static func planReviewStep(isV2Enabled: Bool = OnboardingStepPolicy.isV2Enabled) -> OnboardingStep {
        isV2Enabled ? .planReveal : .planPreview
    }

    func isPlanReviewStep(isV2Enabled: Bool = OnboardingStepPolicy.isV2Enabled) -> Bool {
        switch self {
        case .planPreview:
            return !isV2Enabled
        case .planReveal:
            return isV2Enabled
        default:
            return false
        }
    }

    // MARK: Stage mapping

    var stage: OnboardingStage {
        switch self {
        case .landing, .welcome, .motivation:
            return .start
        case .body:
            return .basics
        case .goal:
            return .goal
        case .activity:
            return .activity
        case .preferences:
            return .preferences
        case .summary, .generatingPlan, .planReveal, .planPreview:
            return .plan
        case .savePlan:
            return .save
        }
    }

    // MARK: Copy

    var title: String {
        switch self {
        case .landing:
            return FormaProductCopy.Onboarding.V2.Landing.title
        case .welcome:
            return FormaProductCopy.Onboarding.V2.Welcome.title
        case .motivation:
            return FormaProductCopy.Onboarding.V2.Motivation.title
        case .body:
            return FormaProductCopy.Onboarding.V2.Body.title
        case .goal:
            return FormaProductCopy.Onboarding.V2.Goal.title
        case .activity:
            return FormaProductCopy.Onboarding.V2.Activity.title
        case .preferences:
            return FormaProductCopy.Onboarding.V2.Preferences.title
        case .summary:
            return FormaProductCopy.Onboarding.V2.Summary.title
        case .generatingPlan:
            return FormaProductCopy.Onboarding.V2.Generating.title
        case .planReveal, .planPreview:
            return FormaProductCopy.Onboarding.V2.PlanReveal.title
        case .savePlan:
            return FormaProductCopy.Onboarding.V2.SavePlan.title
        }
    }

    var subtitle: String {
        switch self {
        case .landing:
            return FormaProductCopy.Onboarding.V2.Landing.subtitle
        case .welcome:
            return FormaProductCopy.Onboarding.V2.Welcome.subtitle
        case .motivation:
            return FormaProductCopy.Onboarding.V2.Motivation.subtitle
        case .body:
            return FormaProductCopy.Onboarding.V2.Body.subtitle
        case .goal:
            return FormaProductCopy.Onboarding.V2.Goal.subtitle
        case .activity:
            return FormaProductCopy.Onboarding.V2.Activity.subtitle
        case .preferences:
            return FormaProductCopy.Onboarding.V2.Preferences.subtitle
        case .summary:
            return FormaProductCopy.Onboarding.V2.Summary.subtitle
        case .generatingPlan:
            return FormaProductCopy.Loading.generatingPlan
        case .planReveal, .planPreview:
            return FormaProductCopy.Onboarding.V2.PlanReveal.subtitle
        case .savePlan:
            return FormaProductCopy.Onboarding.V2.SavePlan.subtitle
        }
    }

    // MARK: Legacy step counter (v1 UI only)

    var progressIndex: Int {
        guard let index = OnboardingStep.legacyFlow.firstIndex(of: self) else {
            return stage.progressIndex
        }
        return index + 1
    }

    static var totalSteps: Int { legacyFlow.count }

    // MARK: Navigation (flow-aware)

    func next(in flow: [OnboardingStep]) -> OnboardingStep? {
        guard let index = flow.firstIndex(of: self), index < flow.count - 1 else {
            return nil
        }
        return flow[index + 1]
    }

    func previous(in flow: [OnboardingStep]) -> OnboardingStep? {
        guard let index = flow.firstIndex(of: self), index > 0 else {
            return nil
        }
        return flow[index - 1]
    }

    func allowsBackNavigation(isV2Enabled: Bool = OnboardingStepPolicy.isV2Enabled) -> Bool {
        switch self {
        case .generatingPlan:
            return false
        case .landing:
            return false
        case .welcome:
            return isV2Enabled
        case .savePlan:
            return isV2Enabled
        default:
            return true
        }
    }

    /// Whether navigating back from this step should clear the generated plan preview.
    func clearsGeneratedPlanWhenNavigatingBack(
        isV2Enabled: Bool = OnboardingStepPolicy.isV2Enabled
    ) -> Bool {
        clearsGeneratedPlanWhenNavigatingBack(in: OnboardingStepPolicy.flow(isV2Enabled: isV2Enabled))
    }

    func clearsGeneratedPlanWhenNavigatingBack(in flow: [OnboardingStep]) -> Bool {
        switch self {
        case .planReveal:
            return flow.contains(.planReveal) && !flow.contains(.planPreview)
        case .planPreview:
            return flow.contains(.planPreview)
        default:
            return false
        }
    }

    func allowsBackNavigation(in flow: [OnboardingStep]) -> Bool {
        switch self {
        case .generatingPlan:
            return false
        case .landing:
            return false
        default:
            return previous(in: flow) != nil
        }
    }

    /// Resolves the back destination, including v2 special cases.
    func backTarget(isV2Enabled: Bool = OnboardingStepPolicy.isV2Enabled) -> OnboardingStep? {
        guard allowsBackNavigation(isV2Enabled: isV2Enabled) else {
            return nil
        }

        if isV2Enabled {
            switch self {
            case .planReveal:
                return .summary
            case .savePlan:
                return .planReveal
            default:
                break
            }
        }

        return previous(in: OnboardingStepPolicy.flow(isV2Enabled: isV2Enabled))
    }

    /// Steps that should not show the standard bottom bar (full-screen moments).
    var usesFullScreenChrome: Bool {
        switch self {
        case .generatingPlan, .landing:
            return true
        default:
            return false
        }
    }

    /// Whether the shared progress header appears above step content.
    var showsProgressHeader: Bool {
        switch self {
        case .landing, .generatingPlan:
            return false
        default:
            return true
        }
    }
}

// MARK: - Flow policy

enum OnboardingStepPolicy {

    static var featureFlagKey: String { OnboardingV2FeatureFlag.enabledKey }

    static var isV2Enabled: Bool { OnboardingV2FeatureFlag.isV2Active }

    static func flow(for scope: OnboardingFlowScope) -> [OnboardingStep] {
        scope.flow
    }

    static func flow(isV2Enabled: Bool = isV2Enabled) -> [OnboardingStep] {
        isV2Enabled ? OnboardingStep.v2Flow : OnboardingStep.legacyFlow
    }

    static var entryStep: OnboardingStep {
        isV2Enabled ? .landing : .welcome
    }

    static func entryStep(for scope: OnboardingFlowScope) -> OnboardingStep {
        scope.entryStep
    }

    static func next(after step: OnboardingStep, isV2Enabled: Bool = isV2Enabled) -> OnboardingStep? {
        step.next(in: flow(isV2Enabled: isV2Enabled))
    }

    static func back(from step: OnboardingStep, isV2Enabled: Bool = isV2Enabled) -> OnboardingStep? {
        step.backTarget(isV2Enabled: isV2Enabled)
    }

    static func contains(_ step: OnboardingStep, isV2Enabled: Bool = isV2Enabled) -> Bool {
        flow(isV2Enabled: isV2Enabled).contains(step)
    }
}
