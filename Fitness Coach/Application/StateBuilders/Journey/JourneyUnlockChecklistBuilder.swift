//
//  JourneyUnlockChecklistBuilder.swift
//  Fitness Coach
//
//  Forma — Builds positive unlock checklist and next-action card state for Journey.
//

import Foundation

enum JourneyUnlockChecklistBuilder {

    struct Input: Equatable {
        var stats: JourneyWeeklyStatsState
        var unlocks: JourneyUnlockPresentationState
        var nextBestAction: JourneyNextBestActionState
        var summary: WeeklyProgressSummary
    }

    static func buildDashboardState(_ input: Input) -> JourneyUnlockDashboardState {
        let showsProminent = !input.unlocks.weeklyReview
        let checklist = showsProminent ? buildChecklist(input) : nil
        let nextActionCard = showsProminent
            ? buildNextActionCard(input)
            : nil

        return JourneyUnlockDashboardState(
            showsProminentNextActionCard: showsProminent,
            nextActionCard: nextActionCard,
            checklist: checklist,
            suppressesMilestonesSection: showsProminent
        )
    }

    // MARK: - Checklist

    static func buildChecklist(_ input: Input) -> JourneyUnlockChecklistState {
        let copy = FormaProductCopy.Journey.Unlock.self
        let stats = input.stats
        let requiredMealDays = JourneyThresholds.requiredMealLoggingDays
        let requiredWeighIns = JourneyThresholds.requiredWeighIns

        var items: [JourneyUnlockChecklistItem] = []

        items.append(
            checklistItem(
                id: "first-weigh-in",
                title: copy.firstWeighInLogged,
                isComplete: stats.weighIns >= 1
            )
        )

        items.append(
            checklistItem(
                id: "first-workout",
                title: copy.firstWorkoutCompleted,
                isComplete: stats.workouts >= 1
            )
        )

        items.append(
            checklistItem(
                id: "first-meal",
                title: copy.firstMealLogged,
                isComplete: stats.mealsLogged >= 1
            )
        )

        items.append(
            mealLoggingDaysItem(
                current: stats.mealLoggingDays,
                required: requiredMealDays
            )
        )

        items.append(
            weighInsItem(
                current: stats.weighIns,
                required: requiredWeighIns
            )
        )

        let completedCount = items.filter(\.isCompleted).count

        return JourneyUnlockChecklistState(
            title: copy.checklistTitle,
            items: items,
            completedCount: completedCount,
            totalCount: items.count,
            accessibilityLabel: copy.checklistAccessibility(
                completed: completedCount,
                total: items.count,
                items: items
            )
        )
    }

    // MARK: - Next action card

    static func buildNextActionCard(_ input: Input) -> JourneyNextActionCardState {
        let copy = FormaProductCopy.Journey.Unlock.self
        let action = input.nextBestAction
        let stats = input.stats
        let cta = UnifiedWeeklyReviewPresentationBuilder.cta(from: action)

        let progressLabel = progressLabel(
            for: action.kind,
            stats: stats
        )
        let detail = nextActionDetail(
            for: action.kind,
            fallback: action.detail
        )

        return JourneyNextActionCardState(
            sectionTitle: copy.nextAchievementSection,
            title: action.title,
            progressLabel: progressLabel,
            detail: detail,
            cta: cta,
            accessibilityLabel: [
                copy.nextAchievementSection,
                action.title,
                progressLabel,
                detail
            ].joined(separator: ". ")
        )
    }

    // MARK: - Locked insights

    static func weightTrendLockedState() -> JourneyInsightLockedState {
        let copy = FormaProductCopy.Journey.Unlock.self
        return JourneyInsightLockedState(
            headline: copy.weightTrendBuildingTitle,
            detail: copy.weightTrendBuildingDetail,
            progressLabel: nil,
            isCompact: true,
            accessibilityLabel: "\(copy.weightTrendBuildingTitle). \(copy.weightTrendBuildingDetail)"
        )
    }

    static func maintenanceLockedState() -> JourneyInsightLockedState {
        let copy = FormaProductCopy.Journey.Unlock.self
        return JourneyInsightLockedState(
            headline: copy.maintenanceLockedTitle,
            detail: nil,
            progressLabel: nil,
            isCompact: true,
            accessibilityLabel: copy.maintenanceLockedTitle
        )
    }

    // MARK: - Private

    private static func checklistItem(
        id: String,
        title: String,
        isComplete: Bool
    ) -> JourneyUnlockChecklistItem {
        let status: JourneyUnlockChecklistItemStatus = isComplete ? .completed : .pending
        let accessibility = isComplete
            ? "\(title). Completed."
            : "\(title). Not yet completed."
        return JourneyUnlockChecklistItem(
            id: id,
            title: title,
            status: status,
            accessibilityLabel: accessibility
        )
    }

    private static func mealLoggingDaysItem(
        current: Int,
        required: Int
    ) -> JourneyUnlockChecklistItem {
        let copy = FormaProductCopy.Journey.Unlock.self
        let title = copy.mealLoggingDays(required: required)
        let status: JourneyUnlockChecklistItemStatus
        if current >= required {
            status = .completed
        } else if current > 0 {
            status = .inProgress(current: current, total: required)
        } else {
            status = .pending
        }

        return JourneyUnlockChecklistItem(
            id: "meal-logging-days",
            title: title,
            status: status,
            accessibilityLabel: copy.rowAccessibility(title: title, status: status)
        )
    }

    private static func weighInsItem(
        current: Int,
        required: Int
    ) -> JourneyUnlockChecklistItem {
        let copy = FormaProductCopy.Journey.Unlock.self
        let remaining = max(required - current, 0)
        let title: String
        let status: JourneyUnlockChecklistItemStatus

        if current >= required {
            title = copy.weighInsComplete(required: required)
            status = .completed
        } else if current > 0 {
            title = copy.moreWeighIns(remaining: remaining)
            status = .inProgress(current: current, total: required)
        } else {
            title = copy.weighInsComplete(required: required)
            status = .pending
        }

        return JourneyUnlockChecklistItem(
            id: "weigh-ins",
            title: title,
            status: status,
            accessibilityLabel: copy.rowAccessibility(title: title, status: status)
        )
    }

    private static func progressLabel(
        for kind: JourneyNextBestActionKind,
        stats: JourneyWeeklyStatsState
    ) -> String {
        let copy = FormaProductCopy.Journey.Unlock.self
        switch kind {
        case .logFirstMeal:
            return copy.mealCountProgress(
                current: stats.mealsLogged,
                total: 1
            )
        case .logMealsConsistently:
            return copy.mealDayProgress(
                current: stats.mealLoggingDays,
                total: JourneyThresholds.requiredMealLoggingDays
            )
        case .logWeightMoreOften:
            return copy.weighInProgress(
                current: stats.weighIns,
                total: JourneyThresholds.requiredWeighIns
            )
        case .completeFirstWorkout:
            return copy.workoutProgress(
                current: stats.workouts,
                total: 1
            )
        case .syncRecoveryData, .keepStreakGoing:
            return copy.mealDayProgress(
                current: stats.mealLoggingDays,
                total: JourneyThresholds.requiredMealLoggingDays
            )
        }
    }

    private static func nextActionDetail(
        for kind: JourneyNextBestActionKind,
        fallback: String?
    ) -> String {
        switch kind {
        case .logFirstMeal:
            return FormaProductCopy.Journey.Unlock.firstMealUnlockDetail
        default:
            return fallback ?? ""
        }
    }
}

// MARK: - Checklist helpers

private extension JourneyUnlockChecklistItem {
    var isCompleted: Bool {
        if case .completed = status { return true }
        return false
    }
}
