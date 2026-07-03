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
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.top, FormaTokens.Spacing.md)
        .padding(.bottom, JourneyLayout.scrollBottomContentPadding)
        .accessibilityIdentifier("journey-dashboard")
    }

    private var visibleSections: [JourneyProductSection] {
        JourneyProductLayout.sectionOrder.filter { section in
            switch section {
            case .milestones:
                return state.showsMilestonesSection
            case .storyTimeline:
                return state.showsStoryTimelineSection
            case .startingEmptyState:
                return state.showsStartingEmptyState
            case .goalProjection:
                return state.showsGoalProjectionSection
            case .transformation, .weeklyReview:
                return true
            }
        }
    }

    @ViewBuilder
    private func sectionView(for section: JourneyProductSection) -> some View {
        switch section {
        case .transformation:
            JourneyTransformationHeroSection(state: state.transformation, onCTA: onCTA)
                .padding(.bottom, JourneyLayout.heroBottomSpacing)
                .onAppear { analyticsCoordinator?.logTransformationViewed() }

        case .goalProjection:
            JourneyGoalProjectionSection(state: state.goalProjection, onCTA: onCTA)
                .onAppear { analyticsCoordinator?.logGoalProjectionViewed() }

        case .weeklyReview:
            JourneyWeeklyReviewSection(review: state.weeklyReview, onCTA: onCTA)
                .onAppear { analyticsCoordinator?.logWeeklyReviewViewed() }

        case .milestones:
            JourneyMilestonesSection(state: state.milestone)
                .onAppear { analyticsCoordinator?.logMilestoneRailViewed() }

        case .storyTimeline:
            JourneyStoryTimelineSection(state: state.storyTimeline)
                .onAppear { analyticsCoordinator?.logTimelineViewed() }

        case .startingEmptyState:
            JourneyStartingEmptyStateView(onGoToToday: onGoToToday)
                .onAppear { analyticsCoordinator?.logStartingEmptyStateViewed() }
        }
    }
}
