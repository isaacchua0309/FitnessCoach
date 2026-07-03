//
//  JourneyDashboardContent.swift
//  Fitness Coach
//
//  Forma — Shared Journey section stack for JourneyView and previews.
//

import SwiftUI

struct JourneyDashboardContent: View {
    let state: JourneyDashboardState
    var healthIntelligenceUIEnabled: Bool = HealthIntelligenceFeatureFlags.isUIEnabled
    var healthIntelligenceSectionState: JourneyHealthIntelligenceSectionState?
    var analyticsCoordinator: JourneyAnalyticsCoordinator?
    var onCTA: (JourneyCTA) -> Void = { _ in }
    var onGoToToday: () -> Void = {}
    var onConnectHealth: (() -> Void)?
    var onWeeklyReviewSelected: ((WeeklyReviewDetailState) -> Void)?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
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

    private var showsHealthIntelligenceSection: Bool {
        JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: healthIntelligenceUIEnabled,
            sectionState: healthIntelligenceSectionState
        )
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
            case .healthIntelligence:
                return showsHealthIntelligenceSection
            case .milestones:
                return state.showsMilestonesSection
            case .weeklyReview:
                return state.showsWeeklyReviewSection
            case .storyTimeline:
                return state.showsStoryTimelineSection
            case .insights:
                return JourneyDashboardCompositionPolicy.showsLegacyInsightsSection(
                    isUIEnabled: healthIntelligenceUIEnabled,
                    sectionState: healthIntelligenceSectionState,
                    dashboardShowsInsights: state.showsInsightSection
                )
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

        case .healthIntelligence:
            if let healthIntelligenceSectionState {
                JourneyHealthIntelligenceSection(
                    state: healthIntelligenceSectionState,
                    onConnectHealth: onConnectHealth,
                    onWeeklyReviewSelected: onWeeklyReviewSelected
                )
                .accessibilityIdentifier("journey-health-intelligence-section")
            }

        case .milestones:
            JourneyMilestonesSection(state: state.milestone)
                .onAppear { analyticsCoordinator?.logMilestoneViewed() }

        case .weeklyReview:
            // Legacy training habit row — pending removal after Health Intelligence rollout.
            JourneyWeeklyReviewSection(
                state: state.weeklyHabit,
                hidesTrainingHabitRow: JourneyDashboardCompositionPolicy.hidesTrainingHabitRow(
                    isUIEnabled: healthIntelligenceUIEnabled,
                    sectionState: healthIntelligenceSectionState
                ),
                onCTA: onCTA
            )
            .onAppear { analyticsCoordinator?.logWeeklyConsistencyViewed() }

        case .storyTimeline:
            JourneyStoryTimelineSection(state: state.storyTimeline)
                .onAppear { analyticsCoordinator?.logStoryViewed() }

        case .insights:
            // Legacy training insights — pending removal after Health Intelligence rollout.
            JourneyInsightsSection(state: state.insight)
                .onAppear { analyticsCoordinator?.logInsightsViewed() }

        case .monthlyRecap:
            // Legacy monthly workout metrics — pending removal after Health Intelligence rollout.
            JourneyMonthlyRecapSection(
                state: state.monthlyRecap,
                hidesWorkoutMetrics: JourneyDashboardCompositionPolicy.hidesWorkoutMetrics(
                    isUIEnabled: healthIntelligenceUIEnabled,
                    sectionState: healthIntelligenceSectionState
                )
            )
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

#if DEBUG
#Preview("Health Intelligence enabled") {
    ScrollView {
        JourneyDashboardContent(
            state: JourneyPreviewData.strongMomentum,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: JourneyHealthIntelligencePreviewData.strongWeek,
            onConnectHealth: {}
        )
    }
    .formaMainTabScrollInsets()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Health Intelligence disabled") {
    ScrollView {
        JourneyDashboardContent(
            state: JourneyPreviewData.strongMomentum,
            healthIntelligenceUIEnabled: false
        )
    }
    .formaMainTabScrollInsets()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
