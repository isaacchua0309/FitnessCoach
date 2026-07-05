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

    private var sectionSpacing: CGFloat {
        verticalSizeClass == .compact
            ? FormaTokens.Spacing.lg
            : TodayLayout.sectionSpacing
    }

    private var showsRecoverySection: Bool {
        TodayReadOnlyCompositionPolicy.showsRecoverySection(
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

    private var showsAppleHealthSetupCard: Bool {
        TodayReadOnlyCompositionPolicy.showsAppleHealthSetupCard(activity: state.activity)
    }

    private var missionForDisplay: TodayMissionState {
        var mission = state.mission
        let nextStep = TodayReadOnlyCompositionPolicy.missionNextStepLine(
            dashboardNextStep: state.mission.nextStepLine,
            healthIntelligenceSection: healthIntelligenceSection
        )
        if !nextStep.isEmpty {
            mission.nextStepLine = nextStep
        }
        return mission
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

        VStack(alignment: .leading, spacing: sectionSpacing) {
            TodayDashboardHeader(
                date: state.date,
                planStatusChip: TodayDashboardHeaderFormatting.planStatusChip(for: state.mission.status)
            )

            missionBlock

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
                onLogFirstMeal: {
                    actionCoordinator.logPrimaryCTATapped()
                    actionCoordinator.performQuickAction(.logMeal)
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

            recoveryBlock

            activityBlock

            if showsAppleHealthSetupCard {
                TodayAppleHealthSetupCard(
                    actionTitle: TodayReadOnlyCompositionPolicy.appleHealthSetupActionTitle(
                        for: state.activity
                    ),
                    onAction: {
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
                mission: missionForDisplay,
                onLogMeal: {
                    actionCoordinator.logPrimaryCTATapped()
                    actionCoordinator.performQuickAction(.logMeal)
                },
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

    @ViewBuilder
    private var recoveryBlock: some View {
        if showsRecoverySection, let healthIntelligenceSection {
            TodayRecoverySection(
                state: healthIntelligenceSection.recoveryCard,
                isLoading: healthIntelligenceSection.isLoading,
                staleDataLabel: healthIntelligenceSection.staleDataLabel
            )
            .onAppear {
                guard !healthIntelligenceSection.isLoading else { return }
                healthIntelligenceAnalyticsCoordinator?.logTodayRecoveryCardViewed()
            }

            if TodayReadOnlyCompositionPolicy.showsHealthWorkoutCard(
                isUIEnabled: isHealthIntelligenceUIEnabled,
                sectionState: healthIntelligenceSection
            ), let workoutCard = healthIntelligenceSection.workoutCard {
                TodayHealthWorkoutCard(
                    state: workoutCard,
                    isLoading: healthIntelligenceSection.isLoading
                )
            }

            if TodayReadOnlyCompositionPolicy.showsStandaloneHIFallback(
                sectionState: healthIntelligenceSection
            ), let fallbackMessage = healthIntelligenceSection.fallbackMessage {
                hiFallbackBanner(message: fallbackMessage)
            }
        }
    }

    @ViewBuilder
    private var activityBlock: some View {
        if showsActivitySection {
            TodayActivitySection(
                activity: state.activity,
                onConnectAppleHealth: {
                    actionCoordinator.onOpenTrainingInsights?()
                },
                includesAppleHealthSetupCard: showsAppleHealthSetupCard
            )
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

    @ViewBuilder
    private func hiFallbackBanner(message: String) -> some View {
        FormaPlanCard {
            Text(message)
                .font(TodayHealthIntelligenceCardTypography.detail)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .healthIntelligenceMultilineText()
                .healthIntelligenceCardInnerPadding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityIdentifier("today-hi-fallback-banner")
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
    static func screen(
        _ state: TodayDashboardState,
        healthIntelligenceSection: TodayHealthIntelligenceSectionState? = nil,
        isHealthIntelligenceUIEnabled: Bool = false
    ) -> some View {
        ScrollView {
            TodayReadOnlyView(
                state: state,
                actionCoordinator: coordinator(),
                healthIntelligenceSection: healthIntelligenceSection,
                isHealthIntelligenceUIEnabled: isHealthIntelligenceUIEnabled,
                onHealthNextBestAction: { _ in }
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

#Preview("Empty day") {
    TodayReadOnlyPreviewSupport.screen(TodayPreviewData.brandNewDay)
}

#Preview("Partial day") {
    TodayReadOnlyPreviewSupport.screen(TodayPreviewData.partialDay)
}

#Preview("Health Intelligence — low recovery") {
    TodayReadOnlyPreviewSupport.screen(
        TodayPreviewData.partialDay,
        healthIntelligenceSection: TodayHealthIntelligencePreviewData.lowRecoveryDay,
        isHealthIntelligenceUIEnabled: true
    )
}

#Preview("Apple Health disconnected") {
    TodayReadOnlyPreviewSupport.screen(TodayPreviewData.healthDisconnected)
}

#Preview("No health data") {
    TodayReadOnlyPreviewSupport.screen(
        TodayPreviewData.brandNewDay,
        healthIntelligenceSection: TodayHealthIntelligencePreviewData.noHealthData,
        isHealthIntelligenceUIEnabled: true
    )
}

#Preview("Large text") {
    TodayReadOnlyPreviewSupport.screen(TodayPreviewData.partialDay)
        .dynamicTypeSize(.accessibility2)
}
#endif
