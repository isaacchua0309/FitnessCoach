//
//  JourneyDashboardState+Presentation.swift
//  Fitness Coach
//
//  Forma — Merges Health Intelligence and freshness into the Journey presentation model.
//

import Foundation

extension JourneyDashboardState {

    func mergingPresentationContext(
        healthIntelligence: JourneyHealthIntelligenceSectionState?,
        freshnessInput: WeeklyProgressFreshnessInput?,
        isAppleHealthConnected: Bool
    ) -> JourneyDashboardState {
        var updated = self

        let recoveryDays = healthIntelligence?.recoveryTimeline.days
            .filter { $0.recoveryScore != nil }
            .count

        updated.screenPresentation = JourneyScreenPresentationBuilder.patchingHealthIntelligence(
            screenPresentation,
            recoveryDaysWithSignals: recoveryDays,
            averageStepsInWeek: nil,
            summary: weeklyProgressSummary,
            insight: insight,
            goalProjection: goalProjection,
            isAppleHealthConnected: isAppleHealthConnected
        )

        if freshnessInput != nil {
            var presentation = updated.screenPresentation
            presentation.sync = JourneyScreenPresentationBuilder.syncPresentation(
                freshnessInput: freshnessInput
            )
            updated.screenPresentation = presentation
        }

        updated.unifiedWeeklyReview = UnifiedWeeklyReviewPresentationBuilder.build(
            UnifiedWeeklyReviewInput(
                summary: weeklyProgressSummary,
                weeklyHabit: weeklyHabit,
                healthReviewCard: healthIntelligence?.weeklyReviewCard,
                healthReviewDetail: healthIntelligence?.weeklyReviewDetail,
                goalDirection: baseline.goalDirection,
                dailyReviewsThisWeekCount: dailyReviewsThisWeekCount,
                freshnessInput: freshnessInput,
                screenPresentation: updated.screenPresentation
            )
        )

        updated.dashboardHero = JourneyDashboardHeroBuilder.build(
            JourneyDashboardHeroBuilder.Input(
                screenPresentation: updated.screenPresentation,
                weeklySummary: weeklyProgressSummary,
                hasProfile: hasProfile
            )
        )
        updated.progressSection = JourneyProgressSectionBuilder.build(
            JourneyProgressSectionBuilder.Input(
                screenPresentation: updated.screenPresentation,
                unifiedWeeklyReview: updated.unifiedWeeklyReview,
                goalProjection: goalProjection,
                connectHealthCTA: JourneyDashboardCompositionPolicy.connectHealthCTA(
                    from: healthIntelligence
                )
            )
        )

        return updated
    }

    func alignedHealthIntelligenceSection(
        _ section: JourneyHealthIntelligenceSectionState?
    ) -> JourneyHealthIntelligenceSectionState? {
        guard var section else { return nil }

        if var card = section.weeklyReviewCard {
            card.dateRangeLabel = screenPresentation.weekly.dateRangeText
            card.confidenceLabel = screenPresentation.copy.confidenceLabel
            section.weeklyReviewCard = card
        }

        if var detail = section.weeklyReviewDetail {
            detail.dateRangeLabel = screenPresentation.weekly.dateRangeText
            detail.confidenceLabel = screenPresentation.copy.confidenceLabel
            section.weeklyReviewDetail = detail
        }

        return section
    }
}
