//
//  PlanReviewStateBuilder.swift
//  Fitness Coach
//
//  Forma — Next Review presentation state.
//

import Foundation

enum PlanReviewStateBuilder {

    private static let reviewIntervalDays = 7
    private static let minimumFoodLogDaysForReview = 3

    static func build(
        profile: UserProfile,
        weekLogs: [DailyLog],
        allWeights: [WeightEntry],
        referenceDate: Date,
        calendar: Calendar
    ) -> PlanReviewState {
        let anchorDate = reviewAnchorDate(profile: profile, fallback: referenceDate)
        let daysSinceAnchor = daysSince(
            anchorDate: anchorDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let daysUntilReview = max(reviewIntervalDays - daysSinceAnchor, 0)
        let hasRecentWeight = PlanConfidenceStateBuilder.hasRecentWeightLog(
            in: allWeights,
            asOf: referenceDate,
            calendar: calendar
        )
        let foodDays = JourneyLogMetrics.foodLoggedDays(in: weekLogs)
        let hasEnoughData = hasRecentWeight && foodDays >= minimumFoodLogDaysForReview
        let isReviewDue = daysSinceAnchor >= reviewIntervalDays

        let headline: String
        if isReviewDue && hasEnoughData {
            headline = FormaProductCopy.PlanMissionControl.planReviewReadyHeadline
        } else {
            headline = FormaProductCopy.PlanMissionControl.planReviewInDays(daysUntilReview)
        }

        let weighInHint = hasRecentWeight
            ? nil
            : FormaProductCopy.PlanMissionControl.planReviewWeighInHint

        var state = PlanReviewState(
            sectionTitle: FormaProductCopy.PlanMissionControl.planReviewSectionTitle,
            headline: headline,
            bodyCopy: FormaProductCopy.PlanMissionControl.planReviewBodyCopy,
            weighInHint: weighInHint,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func reviewAnchorDate(profile: UserProfile, fallback: Date) -> Date {
        if profile.updatedAt.timeIntervalSince1970 > 0 {
            return profile.updatedAt
        }
        if profile.createdAt.timeIntervalSince1970 > 0 {
            return profile.createdAt
        }
        return fallback
    }

    static func daysSince(
        anchorDate: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        let anchorStart = calendar.startOfDay(for: anchorDate)
        let referenceStart = calendar.startOfDay(for: referenceDate)
        return max(calendar.dateComponents([.day], from: anchorStart, to: referenceStart).day ?? 0, 0)
    }

    private static func accessibilitySummary(for state: PlanReviewState) -> String {
        var parts = [state.sectionTitle, state.headline, state.bodyCopy]
        if let weighInHint = state.weighInHint {
            parts.append(weighInHint)
        }
        return parts.joined(separator: ". ")
    }
}
