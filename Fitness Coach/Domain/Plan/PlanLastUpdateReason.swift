//
//  PlanLastUpdateReason.swift
//  Fitness Coach
//
//  Forma — Lightweight reason codes for the most recent plan edit.
//

import Foundation

enum PlanLastUpdateReason: String, Codable, Equatable, Sendable {
    case onboarding
    case goalChanged
    case activityChanged
    case targetsRegenerated
    case planAdjusted
}

enum PlanUpdateReasonResolver {

    private static let weightEpsilonKg = 0.01

    /// Picks the most user-meaningful reason when multiple fields changed.
    static func resolve(baseline: UserProfile, update: UserProfileUpdate) -> PlanLastUpdateReason {
        if goalWeightChanged(baseline: baseline, update: update) {
            return .goalChanged
        }
        if activityLevelChanged(baseline: baseline, update: update) {
            return .activityChanged
        }
        if targetsChanged(baseline: baseline, update: update) {
            return .targetsRegenerated
        }
        return .planAdjusted
    }

    private static func goalWeightChanged(baseline: UserProfile, update: UserProfileUpdate) -> Bool {
        guard let goalWeightKg = update.goalWeightKg else { return false }
        return abs(goalWeightKg - baseline.goalWeightKg) > weightEpsilonKg
    }

    private static func activityLevelChanged(baseline: UserProfile, update: UserProfileUpdate) -> Bool {
        guard let activityLevel = update.activityLevel else { return false }
        return activityLevel != baseline.activityLevel
    }

    private static func targetsChanged(baseline: UserProfile, update: UserProfileUpdate) -> Bool {
        guard let targets = update.targets else { return false }
        return targets != baseline.targets
    }
}

enum PlanLastUpdatedLabelFormatter {

    static func label(
        for date: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
