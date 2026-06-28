//
//  JourneyDashboardContent.swift
//  Fitness Coach
//
//  Forma — Shared Journey section stack for ProgressView and previews.
//

import SwiftUI

struct JourneyDashboardContent: View {
    let state: ProgressDashboardState
    var analyticsCoordinator: JourneyAnalyticsCoordinator?
    var onCTA: (JourneyCTA) -> Void = { _ in }
    var onSelectRange: (Int) -> Void = { _ in }
    var onAnalyticsExpanded: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
            ForEach(JourneyProductLayout.sectionOrder, id: \.self) { section in
                sectionView(for: section)
            }
        }
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.top, FormaTokens.Spacing.md)
        .padding(.bottom, JourneyLayout.scrollBottomContentPadding)
        .accessibilityIdentifier("journey-dashboard")
    }

    @ViewBuilder
    private func sectionView(for section: JourneyProductSection) -> some View {
        switch section {
        case .transformation:
            JourneyTransformationHeroSection(state: state.transformation, onCTA: onCTA)
                .padding(.bottom, JourneyLayout.heroBottomSpacing)
                .onAppear { analyticsCoordinator?.logTransformationViewed() }

        case .weeklyReview:
            JourneyWeeklyReviewSection(review: state.weeklyReview, onCTA: onCTA)
                .onAppear { analyticsCoordinator?.logWeeklyReviewViewed() }

        case .milestones:
            JourneyMilestonesSection(state: state.milestones)
                .onAppear { analyticsCoordinator?.logMilestoneRailViewed() }

        case .storyTimeline:
            JourneyStoryTimelineSection(state: state.storyTimeline)
                .onAppear { analyticsCoordinator?.logTimelineViewed() }

        case .habitInsights:
            JourneyHabitInsightsSection(state: state.habitInsights, onCTA: onCTA)
                .onAppear { analyticsCoordinator?.logHabitInsightViewed() }

        case .whyProgress:
            JourneyWhyProgressSection(state: state.progressAttribution)

        case .beforeToday:
            JourneyBeforeTodaySection(state: state.beforeToday)

        case .personalRecords:
            JourneyPersonalRecordsSection(state: state.personalRecords)

        case .monthlyRecap:
            JourneyMonthlyRecapSection(state: state.monthlyRecap)

        case .journeyLevel:
            JourneyLevelSection(state: state.journeyLevel)

        case .detailedAnalytics:
            JourneyDetailedAnalyticsSection(
                analytics: state.detailedAnalytics,
                selectedRangeDays: state.selectedRangeDays,
                onSelectRange: onSelectRange,
                onAnalyticsExpanded: onAnalyticsExpanded,
                onCTA: onCTA
            )
        }
    }
}
