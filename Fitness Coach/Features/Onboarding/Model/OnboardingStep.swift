//
//  OnboardingStep.swift
//  Fitness Coach
//
//  Forma — Canonical onboarding wizard step graph.
//

import Foundation

enum OnboardingStep: Int, Equatable, Identifiable, Sendable, CaseIterable {

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

    // MARK: - Flow

    static let flow: [OnboardingStep] = [
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

    // MARK: - Stage mapping

    var stage: OnboardingStage {
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
        let copy = FormaProductCopy.Onboarding.Flow.self
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
            return FormaProductCopy.Onboarding.Flow.PlanReveal.title
        case .savePlan:
            return FormaProductCopy.Onboarding.Flow.SavePlan.title
        }
    }

    var subtitle: String {
        let copy = FormaProductCopy.Onboarding.Flow.self
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
            return FormaProductCopy.Onboarding.Flow.PlanReveal.subtitle
        case .savePlan:
            return FormaProductCopy.Onboarding.Flow.SavePlan.subtitle
        }
    }

    // MARK: - Navigation

    func next(in flow: [OnboardingStep]) -> OnboardingStep? {
        guard let index = flow.firstIndex(of: self), index + 1 < flow.count else {
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

    func allowsBackNavigation(
        in flow: [OnboardingStep],
        notBefore floor: OnboardingStep = .introProof
    ) -> Bool {
        backTarget(in: flow, notBefore: floor) != nil
    }

    func backTarget(
        in flow: [OnboardingStep],
        notBefore floor: OnboardingStep = .introProof
    ) -> OnboardingStep? {
        guard allowsBackNavigation(in: flow) else { return nil }

        let target: OnboardingStep?
        switch self {
        case .planReveal:
            target = .review
        case .savePlan:
            target = .planReveal
        default:
            target = previous(in: flow)
        }

        guard let target,
              let targetIndex = flow.firstIndex(of: target),
              let floorIndex = flow.firstIndex(of: floor) else {
            return nil
        }
        return targetIndex >= floorIndex ? target : nil
    }

    private func allowsBackNavigation(in flow: [OnboardingStep]) -> Bool {
        switch self {
        case .generatingPlan, .introProof:
            return false
        default:
            return previous(in: flow) != nil
                || self == .planReveal
                || self == .savePlan
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

    func clearsGeneratedPlanWhenNavigatingBack(in flow: [OnboardingStep]) -> Bool {
        self == .planReveal && flow.contains(.planReveal)
    }
}

// MARK: - Flow policy

enum OnboardingStepPolicy {

    static var flow: [OnboardingStep] { OnboardingStep.flow }

    static func next(after step: OnboardingStep) -> OnboardingStep? {
        step.next(in: flow)
    }

    static func back(
        from step: OnboardingStep,
        notBefore floor: OnboardingStep
    ) -> OnboardingStep? {
        step.backTarget(in: flow, notBefore: floor)
    }
}
