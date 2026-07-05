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
    var weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator?
    var healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    var onCTA: (JourneyCTA) -> Void = { _ in }
    var onWeeklyProgressCTA: (WeeklyProgressCTA) -> Void = { _ in }
    var onGoToToday: () -> Void = {}
    var onConnectHealth: (() -> Void)?
    var onOpenWeeklyProgressDetail: (() -> Void)?
    var weeklyProgressFreshnessInput: WeeklyProgressFreshnessInput?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
            if state.screenPresentation.sync.showsHealthSyncNotice,
               let notice = state.screenPresentation.sync.healthSyncNotice {
                JourneyCard(elevation: .quiet) {
                    Text(notice)
                        .font(JourneyTypography.cardSupporting)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .healthIntelligenceMultilineText()
                }
                .accessibilityIdentifier("journey-sync-notice")
            }

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

    private var unifiedWeeklyReview: UnifiedWeeklyReviewState {
        state.unifiedWeeklyReview
    }

    private var visibleSections: [JourneyProductSection] {
        JourneyProductLayout.sectionOrder.filter { section in
            switch section {
            case .hero:
                return state.showsDashboardHeroSection
            case .nextAction:
                return state.showsNextActionSection
            case .weeklyProgress:
                return state.showsWeeklyProgressSection
            case .progress:
                return state.showsProgressSection
            case .highlights:
                return JourneyDashboardCompositionPolicy.showsHighlightsSection(
                    isUIEnabled: healthIntelligenceUIEnabled,
                    sectionState: healthIntelligenceSectionState
                )
            case .storyTimeline:
                return state.showsStoryTimelineSection
            case .chapters:
                return state.showsChapterSection
            }
        }
    }

    @ViewBuilder
    private func sectionView(for section: JourneyProductSection) -> some View {
        switch section {
        case .hero:
            JourneyDashboardHeroSection(state: state.dashboardHero)
                .onAppear { analyticsCoordinator?.logHeroViewed() }

        case .nextAction:
            if let nextActionCard = state.screenPresentation.unlockDashboard.nextActionCard {
                VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
                    JourneySectionLabel(
                        title: FormaProductCopy.Journey.Unlock.nextAchievementSection
                    )
                    JourneyNextActionCard(
                        state: nextActionCard,
                        onCTA: onWeeklyProgressCTA
                    )
                }
            }

        case .weeklyProgress:
            ThisWeekSection(
                state: unifiedWeeklyReview,
                summary: state.weeklyProgressSummary,
                weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator,
                freshnessInput: weeklyProgressFreshnessInput,
                onPrimaryCTA: onWeeklyProgressCTA,
                onOpenWeeklyReviewDetail: onOpenWeeklyProgressDetail
            )

        case .progress:
            JourneyProgressSection(
                state: resolvedProgressSection,
                onConnectHealth: onConnectHealth
            )
            .onAppear { analyticsCoordinator?.logProjectionViewed() }

        case .highlights:
            if let healthIntelligenceSectionState {
                JourneyHighlightsSection(
                    state: healthIntelligenceSectionState.milestones,
                    isLoading: healthIntelligenceSectionState.isLoading
                )
                .onAppear { analyticsCoordinator?.logMilestoneViewed() }
            }

        case .storyTimeline:
            JourneyStoryTimelineSection(state: state.storyTimeline)
                .onAppear { analyticsCoordinator?.logStoryViewed() }

        case .chapters:
            JourneyChapterSection(state: state.chapter)
                .onAppear { analyticsCoordinator?.logChapterViewed() }
        }
    }

    private var resolvedProgressSection: JourneyProgressSectionState {
        var progress = state.progressSection
        if progress.connectHealthCTA == nil {
            progress.connectHealthCTA = JourneyDashboardCompositionPolicy.connectHealthCTA(
                from: healthIntelligenceSectionState
            )
        }
        return progress
    }
}

#if DEBUG
#Preview("Strong momentum") {
    ScrollView {
        JourneyDashboardContent(
            state: JourneyPreviewData.strongMomentum,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: JourneyHealthIntelligencePreviewData.strongWeek,
            onConnectHealth: {}
        )
    }
    .formaJourneyScrollInsets()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Brand new user") {
    ScrollView {
        JourneyDashboardContent(
            state: JourneyPreviewData.brandNewUser,
            healthIntelligenceUIEnabled: false
        )
    }
    .formaJourneyScrollInsets()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
