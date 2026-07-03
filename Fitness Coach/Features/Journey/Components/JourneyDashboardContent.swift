//
//  JourneyDashboardContent.swift
//  Fitness Coach
//
//  Forma — Shared Journey section stack for JourneyView and previews.
//

import SwiftUI

struct JourneyDashboardContent: View {
    let state: JourneyDashboardState
    var analyticsCoordinator: JourneyAnalyticsCoordinator?
    var onCTA: (JourneyCTA) -> Void = { _ in }
    var onGoToToday: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
            ForEach(visibleSections, id: \.self) { section in
                sectionView(for: section)
            }
        }
        .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.top, FormaTokens.Spacing.md)
        .padding(.bottom, JourneyLayout.scrollBottomContentPadding)
        .accessibilityIdentifier("journey-dashboard")
    }

    private var visibleSections: [JourneyProductSection] {
        JourneyProductLayout.sectionOrder.filter { section in
            switch section {
            case .header:
                return true
            case .transformation:
                return true
            case .goalProjection:
                return state.showsGoalProjectionSection
            case .milestones:
                return state.showsMilestonesSection
            case .weeklyReview:
                return state.showsWeeklyReviewSection
            case .storyTimeline:
                return state.showsStoryTimelineSection
            case .insights:
                return state.showsInsightSection
            case .monthlyRecap:
                return state.showsMonthlyRecapSection
            case .chapters:
                return state.showsChapterSection
            case .startingEmptyState:
                return state.showsStartingEmptyState
            }
        }
    }

    @ViewBuilder
    private func sectionView(for section: JourneyProductSection) -> some View {
        switch section {
        case .header:
            JourneyHeaderSection(state: state.header)

        case .transformation:
            VStack(alignment: .leading, spacing: JourneyLayout.heroStackSpacing) {
                if state.showsMomentumSection {
                    JourneyMomentumStrip(state: state.momentum)
                }
                JourneyTransformationHeroSection(state: state.transformation, onCTA: onCTA)
            }
            .padding(.bottom, JourneyLayout.heroBottomSpacing)
            .onAppear { analyticsCoordinator?.logHeroViewed() }

        case .goalProjection:
            JourneyGoalProjectionSection(state: state.goalProjection, onCTA: onCTA)
                .onAppear { analyticsCoordinator?.logProjectionViewed() }

        case .milestones:
            JourneyMilestonesSection(state: state.milestone)
                .onAppear { analyticsCoordinator?.logMilestoneViewed() }

        case .weeklyReview:
            JourneyWeeklyReviewSection(state: state.weeklyHabit, onCTA: onCTA)
                .onAppear { analyticsCoordinator?.logWeeklyConsistencyViewed() }

        case .storyTimeline:
            JourneyStoryTimelineSection(state: state.storyTimeline)
                .onAppear { analyticsCoordinator?.logStoryViewed() }

        case .insights:
            JourneyInsightsSection(state: state.insight)
                .onAppear { analyticsCoordinator?.logInsightsViewed() }

        case .monthlyRecap:
            JourneyMonthlyRecapSection(state: state.monthlyRecap)
                .onAppear { analyticsCoordinator?.logMonthlyRecapViewed() }

        case .chapters:
            JourneyChapterSection(state: state.chapter)
                .onAppear { analyticsCoordinator?.logChapterViewed() }

        case .startingEmptyState:
            JourneyStartingEmptyStateView {
                analyticsCoordinator?.logGoToTodayTapped()
                onGoToToday()
            }
        }
    }
}
