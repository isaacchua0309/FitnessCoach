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
    let onOpenJourney: () -> Void
    let onOpenPlan: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var sectionSpacing: CGFloat {
        verticalSizeClass == .compact
            ? FormaTokens.Spacing.lg
            : TodayLayout.sectionSpacing
    }

    init(
        state: TodayDashboardState,
        actionCoordinator: TodayActionCoordinator,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        appleHealthWorkoutCount: Int? = nil,
        onOpenJourney: @escaping () -> Void = {},
        onOpenPlan: @escaping () -> Void = {}
    ) {
        self.state = state
        self.actionCoordinator = actionCoordinator
        self.onOpenJourney = onOpenJourney
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            TodayDashboardHeader(date: state.date)

            VStack(alignment: .leading, spacing: TodayLayout.primaryActionZoneSpacing) {
                missionBlock

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

            TodayQuickActionsSection(
                menuItems: state.quickActions.items,
                onSelect: { kind in
                    actionCoordinator.performQuickAction(kind)
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
                },
                onLogFirstMeal: {
                    actionCoordinator.performQuickAction(.manualEntry)
                }
            )

            TodayReadOnlyProgressSection(
                macros: state.macroHydration.macroSummary,
                water: state.macroHydration.waterSummary,
                calorieSummary: state.mission.calorieSummary
            )

            TodayActivitySection(
                activity: state.activity,
                onConnectAppleHealth: {
                    actionCoordinator.onOpenTrainingInsights?()
                }
            )

            reinforcementBlock
        }
    }

    private var missionBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.statusZoneSpacing) {
            TodayMissionHero(
                mission: state.mission,
                suppressLogMealCTA: Self.suppressesHeroLogMealCTA(for: state.nextBestAction),
                onLogMeal: {
                    actionCoordinator.logPrimaryCTATapped()
                    actionCoordinator.performQuickAction(.manualEntry)
                },
                onViewed: {
                    actionCoordinator.logMissionViewed()
                }
            )

            if state.emptyContext.showsWeightReminder {
                TodayInlineEmptyCard(
                    copy: TodayEmptyStateFormatting.copy(for: .noRecentWeight),
                    onAction: {
                        actionCoordinator.performQuickAction(.logWeight)
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
            TodayVictorySection(
                victory: state.victory,
                onViewed: {
                    actionCoordinator.logDailyVictoryViewed()
                }
            )

            TodaySmartCoachBanner(
                smartCoach: state.smartCoach,
                onOpenCoach: { prefill in
                    actionCoordinator.onOpenCoach?(prefill)
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
#endif
