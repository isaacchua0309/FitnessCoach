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

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.sectionSpacing) {
            TodayCaloriesHero(
                calories: state.calorieSummary,
                coachSummary: state.coachingNote ?? state.dailyBrief.recommendation
            )

            TodayGoalChecklist(
                goals: TodayGoalsBuilder.goals(from: state),
                onGoalTap: { kind in
                    onOpenCoach(TodayCoachPrompt.forGoal(kind))
                }
            )

            TodayReadOnlyProgressSection(
                macros: state.macroSummary,
                water: state.waterSummary
            )

            TodayMealsPreview(
                entries: state.foodEntries,
                previewLimit: 3,
                onAskCoach: {
                    onOpenCoach(TodayCoachPrompt.logMeal)
                }
            )

            AskCoachCTA {
                onOpenCoach(nil)
            }
        }
    }
}

#Preview {
    ScrollView {
        TodayReadOnlyView(state: TodayPreviewData.state) { _ in }
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, 16)
    }
}
