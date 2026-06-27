//
//  OnboardingAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed onboarding analytics events and safe property bag.
//

import Foundation

enum OnboardingAnalyticsEvent: String, Sendable {
    case started = "onboarding_started"
    case stepViewed = "onboarding_step_viewed"
    case stepCompleted = "onboarding_step_completed"
    case feedbackShown = "onboarding_feedback_shown"
    case planGenerated = "onboarding_plan_generated"
    case planRevealed = "onboarding_plan_revealed"
    case profileSavedLocal = "onboarding_profile_saved_local"
    case signInStarted = "onboarding_sign_in_started"
    case signInCompleted = "onboarding_sign_in_completed"
    case signInCancelled = "onboarding_sign_in_cancelled"
    case completed = "onboarding_completed"
}

enum OnboardingAnalyticsEntry: String, Sendable {
    case preAuth
    case postAuth
}

struct OnboardingAnalyticsProperties: Sendable {
    var step: String?
    var stage: String?
    var durationMs: Int?
    var entry: OnboardingAnalyticsEntry?
    var goalDirection: String?
    var isAggressive: String?
    var estimatedWeeks: String?
    var loggingMode: String?
    var feedbackKind: String?
    var completionPath: String?
    var v2Enabled: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let step { parameters["step"] = step }
        if let stage { parameters["stage"] = stage }
        if let durationMs { parameters["durationMs"] = String(durationMs) }
        if let entry { parameters["entry"] = entry.rawValue }
        if let goalDirection { parameters["goalDirection"] = goalDirection }
        if let isAggressive { parameters["isAggressive"] = isAggressive }
        if let estimatedWeeks { parameters["estimatedWeeks"] = estimatedWeeks }
        if let loggingMode { parameters["loggingMode"] = loggingMode }
        if let feedbackKind { parameters["feedbackKind"] = feedbackKind }
        if let completionPath { parameters["completionPath"] = completionPath }
        if let v2Enabled { parameters["v2Enabled"] = v2Enabled }
        return parameters
    }
}

protocol OnboardingAnalyticsLogging: Sendable {
    func log(_ event: OnboardingAnalyticsEvent, properties: OnboardingAnalyticsProperties)
}

enum OnboardingAnalyticsContextBuilder {

    static func goalDirection(from formState: OnboardingFormState) -> String? {
        guard let current = formState.parsedCurrentWeightKg,
              let goal = formState.parsedGoalWeightKg else {
            return nil
        }
        switch OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: current,
            goalWeightKg: goal
        ) {
        case .cut: return "cut"
        case .maintain: return "maintain"
        case .gain: return "gain"
        }
    }

    static func loggingMode(from formState: OnboardingFormState) -> String? {
        let modes = formState.loggingPreferences.map(\.rawValue).sorted()
        guard !modes.isEmpty else { return nil }
        return modes.joined(separator: ",")
    }

    static func estimatedWeeks(from revealState: OnboardingPlanRevealState?) -> String? {
        guard let label = revealState?.estimatedWeeksLabel else { return nil }
        let digits = label.filter(\.isNumber)
        return digits.isEmpty ? nil : digits
    }

    static func planProperties(
        formState: OnboardingFormState,
        plan: CalorieTargetResult,
        revealState: OnboardingPlanRevealState?
    ) -> OnboardingAnalyticsProperties {
        OnboardingAnalyticsProperties(
            goalDirection: goalDirection(from: formState),
            isAggressive: String(plan.isAggressive),
            estimatedWeeks: estimatedWeeks(from: revealState),
            loggingMode: loggingMode(from: formState)
        )
    }

    static func feedbackKind(for step: OnboardingStep, formState: OnboardingFormState) -> String? {
        switch step {
        case .motivation:
            return formState.selectedMotivations.isEmpty ? nil : "motivation"
        case .body:
            return formState.canAdvance(from: .body) ? "body" : nil
        case .goal:
            return formState.canAdvance(from: .goal) ? "goal" : nil
        case .activity:
            return "activity"
        case .preferences:
            return formState.loggingPreferences.isEmpty ? nil : "preferences"
        default:
            return nil
        }
    }
}
