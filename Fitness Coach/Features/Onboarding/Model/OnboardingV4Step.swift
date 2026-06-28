//
//  OnboardingV4Step.swift
//  Fitness Coach
//
//  Forma — Marketing-first onboarding v4 step graph (navigation skeleton).
//

import Foundation

/// Coarse journey phase for the v4 progress header.
enum OnboardingV4Stage: String, CaseIterable, Equatable, Sendable, Identifiable {
    case start
    case body
    case destination
    case activity
    case proof
    case plan
    case save

    var id: String { rawValue }

    var progressIndex: Int {
        switch self {
        case .start: return 1
        case .body: return 2
        case .destination: return 3
        case .activity: return 4
        case .proof: return 5
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
        case .body:
            return "Your basics"
        case .destination:
            return "Your destination"
        case .activity:
            return "Activity"
        case .proof:
            return "Why Forma"
        case .plan:
            return "Your plan"
        case .save:
            return "Save your plan"
        }
    }
}

enum OnboardingV4Step: Int, Equatable, Identifiable, Sendable, CaseIterable {

    case introProof = 300
    case heightWeight = 301
    case targetWeight = 302
    case targetEncouragement = 303
    case birthday = 304
    case activityLevel = 305
    case appleHealth = 306
    case almostThere = 307
    case formaProof = 308
    case review = 309
    case generatingPlan = 310
    case planReveal = 311
    case savePlan = 312

    var id: Int { rawValue }

    // MARK: - Flows

    static let fullFlow: [OnboardingV4Step] = [
        .introProof,
        .heightWeight,
        .targetWeight,
        .targetEncouragement,
        .birthday,
        .activityLevel,
        .appleHealth,
        .almostThere,
        .formaProof,
        .review,
        .generatingPlan,
        .planReveal,
        .savePlan
    ]

    /// Value-first teaser ends after intro proof before sign-in handoff.
    static let valueFirstTeaserFlow: [OnboardingV4Step] = [.introProof]

    /// Post-auth continuation (skips intro proof).
    static let postAuthFlow: [OnboardingV4Step] = [
        .heightWeight,
        .targetWeight,
        .targetEncouragement,
        .birthday,
        .activityLevel,
        .appleHealth,
        .almostThere,
        .formaProof,
        .review,
        .generatingPlan,
        .planReveal,
        .savePlan
    ]

    static func flow(for scope: OnboardingFlowScope) -> [OnboardingV4Step] {
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

    static func flowForActiveScope(
        scope: OnboardingFlowScope = OnboardingFlowScope.resolve(
            routingMode: OnboardingV2FeatureFlag.routingMode,
            entry: .preAuth
        )
    ) -> [OnboardingV4Step] {
        flow(for: scope)
    }

    // MARK: - Stage mapping

    var stage: OnboardingV4Stage {
        switch self {
        case .introProof:
            return .start
        case .heightWeight, .birthday:
            return .body
        case .targetWeight, .targetEncouragement:
            return .destination
        case .activityLevel, .appleHealth:
            return .activity
        case .almostThere, .formaProof:
            return .proof
        case .review, .generatingPlan, .planReveal:
            return .plan
        case .savePlan:
            return .save
        }
    }

    // MARK: - Copy

    var title: String {
        let copy = FormaProductCopy.Onboarding.V4.self
        switch self {
        case .introProof:
            return copy.IntroProof.title
        case .heightWeight:
            return copy.HeightWeight.title
        case .targetWeight:
            return copy.TargetWeight.title
        case .targetEncouragement:
            return copy.TargetEncouragement.fallbackTitle
        case .birthday:
            return copy.Birthday.title
        case .activityLevel:
            return copy.Activity.title
        case .appleHealth:
            return copy.AppleHealth.title
        case .almostThere:
            return copy.AlmostThere.title
        case .formaProof:
            return copy.FormaProof.title
        case .review:
            return copy.Summary.title
        case .generatingPlan:
            return FormaProductCopy.Onboarding.V2.Generating.title
        case .planReveal:
            return FormaProductCopy.Onboarding.V3.PlanReveal.title
        case .savePlan:
            return FormaProductCopy.Onboarding.V3.SavePlan.title
        }
    }

    var subtitle: String {
        let copy = FormaProductCopy.Onboarding.V4.self
        switch self {
        case .introProof:
            return copy.IntroProof.subtitle
        case .heightWeight:
            return copy.HeightWeight.subtitle
        case .targetWeight:
            return copy.TargetWeight.subtitle
        case .targetEncouragement:
            return copy.TargetEncouragement.subtitle
        case .birthday:
            return copy.Birthday.subtitle
        case .activityLevel:
            return copy.Activity.subtitle
        case .appleHealth:
            return copy.AppleHealth.subtitle
        case .almostThere:
            return copy.AlmostThere.subtitle
        case .formaProof:
            return copy.FormaProof.subtitle
        case .review:
            return copy.Summary.subtitle
        case .generatingPlan:
            return FormaProductCopy.Loading.generatingPlan
        case .planReveal:
            return FormaProductCopy.Onboarding.V3.PlanReveal.subtitle
        case .savePlan:
            return FormaProductCopy.Onboarding.V3.SavePlan.subtitle
        }
    }

    // MARK: - Navigation

    func next(in flow: [OnboardingV4Step]) -> OnboardingV4Step? {
        guard let index = flow.firstIndex(of: self), index + 1 < flow.count else {
            return nil
        }
        return flow[index + 1]
    }

    func previous(in flow: [OnboardingV4Step]) -> OnboardingV4Step? {
        guard let index = flow.firstIndex(of: self), index > 0 else {
            return nil
        }
        return flow[index - 1]
    }

    func allowsBackNavigation(in flow: [OnboardingV4Step]) -> Bool {
        switch self {
        case .generatingPlan, .introProof:
            return false
        default:
            return previous(in: flow) != nil
        }
    }

    func backTarget(in flow: [OnboardingV4Step]) -> OnboardingV4Step? {
        guard allowsBackNavigation(in: flow) else { return nil }

        switch self {
        case .planReveal:
            return .review
        case .savePlan:
            return .planReveal
        default:
            return previous(in: flow)
        }
    }

    var usesFullScreenChrome: Bool {
        switch self {
        case .generatingPlan, .introProof:
            return true
        default:
            return false
        }
    }

    var showsProgressHeader: Bool {
        switch self {
        case .introProof, .generatingPlan, .planReveal, .savePlan, .targetEncouragement:
            return false
        default:
            return true
        }
    }

    func clearsGeneratedPlanWhenNavigatingBack(in flow: [OnboardingV4Step]) -> Bool {
        self == .planReveal && flow.contains(.planReveal)
    }
}

// MARK: - Flow policy

enum OnboardingV4StepPolicy {

    static var isActive: Bool { OnboardingV4FeatureFlag.isActive }

    static func flow(for scope: OnboardingFlowScope) -> [OnboardingV4Step] {
        OnboardingV4Step.flow(for: scope)
    }

    static func entryStep(for scope: OnboardingFlowScope) -> OnboardingV4Step {
        scope.usesV4Steps ? (OnboardingV4Step.flow(for: scope).first ?? .introProof) : .introProof
    }

    static func next(after step: OnboardingV4Step, in flow: [OnboardingV4Step]) -> OnboardingV4Step? {
        step.next(in: flow)
    }

    static func back(from step: OnboardingV4Step, in flow: [OnboardingV4Step]) -> OnboardingV4Step? {
        step.backTarget(in: flow)
    }
}
