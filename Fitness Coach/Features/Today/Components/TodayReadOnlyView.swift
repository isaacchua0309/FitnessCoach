//
//  TodayReadOnlyView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Today dashboard. Mutations route through TodayActionCoordinator.
//
//  Section order: see `TodayDashboardSectionOrder`.
//

import SwiftUI

struct TodayReadOnlyView: View {
    let state: TodayDashboardState
    let actionCoordinator: TodayActionCoordinator
    let healthIntelligenceSection: TodayHealthIntelligenceSectionState?
    let isHealthIntelligenceUIEnabled: Bool
    var healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    let onHealthNextBestAction: ((TodayHealthNextBestActionDestination) -> Void)?
    let onOpenJourney: () -> Void
    let onOpenPlan: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private var sectionSpacing: CGFloat {
        verticalSizeClass == .compact
            ? FormaTokens.Spacing.lg
            : TodayLayout.sectionSpacing
    }

    private var showsHealthIntelligence: Bool {
        TodayReadOnlyCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: isHealthIntelligenceUIEnabled,
            sectionState: healthIntelligenceSection
        )
    }

    private var showsLegacyNextBestAction: Bool {
        TodayReadOnlyCompositionPolicy.showsLegacyNextBestAction(
            isUIEnabled: isHealthIntelligenceUIEnabled,
            sectionState: healthIntelligenceSection
        )
    }

    private var showsActivitySection: Bool {
        TodayReadOnlyCompositionPolicy.showsActivitySection(
            isUIEnabled: isHealthIntelligenceUIEnabled,
            sectionState: healthIntelligenceSection,
            activity: state.activity
        )
    }

    init(
        state: TodayDashboardState,
        actionCoordinator: TodayActionCoordinator,
        healthIntelligenceSection: TodayHealthIntelligenceSectionState? = nil,
        isHealthIntelligenceUIEnabled: Bool = false,
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        onHealthNextBestAction: ((TodayHealthNextBestActionDestination) -> Void)? = nil,
        onOpenJourney: @escaping () -> Void = {},
        onOpenPlan: @escaping () -> Void = {}
    ) {
        self.state = state
        self.actionCoordinator = actionCoordinator
        self.healthIntelligenceSection = healthIntelligenceSection
        self.isHealthIntelligenceUIEnabled = isHealthIntelligenceUIEnabled
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
        self.onHealthNextBestAction = onHealthNextBestAction
        self.onOpenJourney = onOpenJourney
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: sectionSpacing) {
            TodayDashboardHeader(date: state.date)

            if showsHealthIntelligence, let healthIntelligenceSection {
                TodayHealthIntelligenceSection(
                    state: healthIntelligenceSection,
                    healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
                    onNextBestAction: onHealthNextBestAction
                )
            }

            VStack(alignment: .leading, spacing: TodayLayout.primaryActionZoneSpacing) {
                missionBlock

                if showsLegacyNextBestAction {
                TodayNextActionSection(
                    action: state.nextBestAction,
                    onPrimaryCTA: {
                        actionCoordinator.handleCTA(
                            state.nextBestAction.primaryCTA,
                            from: state.nextBestAction
                        )
                    },
                    onSecondaryCTA: { cta in
                        actionCoordinator.handleCTA(cta, from: state.nextBestAction)
                    },
                    onViewed: {
                        actionCoordinator.logNextActionViewed(for: state.nextBestAction)
                    }
                )
                }
            }

            TodayWaterQuickLogSection(
                water: state.macroHydration.waterSummary,
                presetAmountsMl: TodayActionCoordinator.defaultWaterPresetAmountsMl,
                onAddWater: { amountMl in
                    actionCoordinator.addWater(amountMl: amountMl)
                }
            )

            TodayMealsPreview(
                entries: state.meals.entries,
                date: state.date,
                mealsEmptyKind: state.emptyContext.mealsEmptyKind,
                onAddMeal: { mealType in
                    actionCoordinator.logMeal(for: mealType)
                },
                onEditEntry: { entry in
                    actionCoordinator.openEditFood(entry)
                },
                onDeleteEntry: { entry in
                    actionCoordinator.requestDeleteFood(entry)
                }
            )

            TodayReadOnlyProgressSection(
                macros: state.macroHydration.macroSummary,
                water: state.macroHydration.waterSummary,
                calorieSummary: state.mission.calorieSummary
            )

            if showsActivitySection {
                TodayActivitySection(
                    activity: state.activity,
                    onConnectAppleHealth: {
                        actionCoordinator.onOpenTrainingInsights?()
                    }
                )
            }

            reinforcementBlock
        }
        .todayLiveTheme()
    }

    private var missionBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.statusZoneSpacing) {
            TodayMissionHero(
                mission: state.mission,
                onLogMeal: {
                    actionCoordinator.logPrimaryCTATapped()
                    actionCoordinator.performQuickAction(.logMeal)
                },
                suppressLogMealCTA: Self.suppressesHeroLogMealCTA(for: state.nextBestAction),
                onViewed: {
                    actionCoordinator.logMissionViewed()
                }
            )

            if state.emptyContext.showsWeightReminder {
                TodayInlineEmptyCard(
                    copy: TodayEmptyStateFormatting.copy(for: .noRecentWeight),
                    onAction: {
                        actionCoordinator.presentLogWeight()
                    }
                )
            }

            if let goalConnection = state.goalConnection {
                TodayGoalConnectionRow(
                    connection: goalConnection,
                    onOpenJourney: onOpenJourney,
                    onOpenPlan: onOpenPlan,
                    onTapped: { destination in
                        actionCoordinator.logGoalConnectionTapped(destination: destination)
                    }
                )
            }
        }
    }

    private var reinforcementBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.reinforcementSpacing) {
            TodayYesterdayReviewSection(
                state: state.yesterdayReview,
                isGenerating: actionCoordinator.isGeneratingYesterdayReview,
                onViewReview: { review in
                    actionCoordinator.viewYesterdayReview(review)
                },
                onGenerateReview: { date in
                    actionCoordinator.generateYesterdayReview(for: date)
                },
                onViewed: {
                    actionCoordinator.logYesterdayReviewViewed()
                }
            )

            TodayVictorySection(
                victory: state.victory,
                onViewed: {
                    actionCoordinator.logDailyVictoryViewed()
                }
            )

            TodaySmartCoachBanner(
                smartCoach: state.smartCoach,
                onOpenCoach: { intent in
                    actionCoordinator.onOpenCoach?(intent)
                },
                onViewed: {
                    actionCoordinator.logSmartCoachViewed()
                }
            )

            TodayEndOfDayWrapUpSection(
                wrapUp: state.endOfDay,
                onOpenJourney: onOpenJourney,
                onViewed: {
                    actionCoordinator.logEndOfDayWrapViewed()
                }
            )
        }
    }

    /// Hides the hero log-meal chip when Next Best Action already offers a meal-logging primary CTA.
    private static func suppressesHeroLogMealCTA(for action: TodayNextBestActionState) -> Bool {
        switch action.primaryCTA {
        case .logMeal, .scanFood:
            return true
        case .addWater, .logWorkout, .logWeight, .openHealth, .reviewToday, .none:
            return false
        }
    }
}

#if DEBUG
enum TodayReadOnlyPreviewSupport {
    static func coordinator() -> TodayActionCoordinator {
        TodayActionCoordinator(
            actionCenter: try! AppContainer(inMemory: true).actionCenter
        )
    }

    @ViewBuilder
    static func screen(_ state: TodayDashboardState) -> some View {
        ScrollView {
            TodayReadOnlyView(
                state: state,
                actionCoordinator: coordinator()
            )
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, TodayLayout.bottomScrollPadding)
        }
        .formaMainTabScrollInsets()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
    }
}

#Preview("Health Intelligence enabled") {
    ScrollView {
        TodayReadOnlyView(
            state: TodayPreviewData.partialDay,
            actionCoordinator: TodayActionCoordinator(
                actionCenter: try! AppContainer(inMemory: true).actionCenter
            ),
            healthIntelligenceSection: TodayHealthIntelligencePreviewData.workoutDay,
            isHealthIntelligenceUIEnabled: true,
            onHealthNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
