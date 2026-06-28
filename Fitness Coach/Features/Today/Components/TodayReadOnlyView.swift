//
//  TodayReadOnlyView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Today dashboard. All updates route to Coach.
//

import SwiftUI

struct TodayReadOnlyView: View {
    let state: TodayDashboardState
    let onOpenCoach: (String?) -> Void
    let onOpenTrainingInsights: () -> Void

    init(
        state: TodayDashboardState,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        appleHealthWorkoutCount: Int? = nil,
        onOpenCoach: @escaping (String?) -> Void,
        onOpenTrainingInsights: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onOpenCoach = onOpenCoach
        self.onOpenTrainingInsights = onOpenTrainingInsights
    }

    private var showsGenericCoachCTA: Bool {
        TodayCoachCTAPolicy.showsGenericCoachCTA(
            foodEntries: state.meals.entries,
            nextBestAction: state.nextBestAction
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.zoneSpacing) {
            statusZone

            TodayNextActionSection(
                action: state.nextBestAction,
                onCTA: handleNextActionCTA
            )

            loggedItemsZone

            if showsGenericCoachCTA {
                AskCoachCTA {
                    onOpenCoach(nil)
                }
            }
        }
    }

    // MARK: - Zones

    /// Status: Today's Mission hero.
    private var statusZone: some View {
        TodayMissionHero(
            mission: state.mission,
            proteinProgress: state.macroBalance.macroSummary.protein,
            mealsEmpty: state.meals.isEmpty
        )
    }

    /// Logged items: measurement targets + meal timeline.
    private var loggedItemsZone: some View {
        VStack(alignment: .leading, spacing: TodayLayout.loggedZoneSpacing) {
            TodayReadOnlyProgressSection(
                macros: state.macroBalance.macroSummary,
                water: state.macroBalance.waterSummary
            )

            TodayMealsPreview(
                entries: state.meals.entries,
                previewLimit: 3,
                onLogMeal: {
                    onOpenCoach(TodayCoachPrompt.logMeal())
                }
            )
        }
    }

    private func handleNextActionCTA(_ cta: NextBestActionCTA) {
        switch cta {
        case .logMeal(let prefill):
            onOpenCoach(prefill)
        case .scanFood:
            onOpenCoach(TodayCoachPrompt.scanFood)
        case .addWater:
            onOpenCoach(TodayCoachPrompt.logWater)
        case .logWeight:
            onOpenCoach(TodayCoachPrompt.logWeight)
        case .openHealth:
            onOpenTrainingInsights()
        case .reviewToday:
            onOpenCoach(TodayCoachPrompt.reviewToday)
        case .none:
            break
        }
    }
}

#Preview {
    ScrollView {
        TodayReadOnlyView(state: TodayPreviewData.state) { _ in }
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Small phone") {
    ScrollView {
        TodayReadOnlyView(state: TodayPreviewData.state) { _ in }
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .frame(width: 320)
    }
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
