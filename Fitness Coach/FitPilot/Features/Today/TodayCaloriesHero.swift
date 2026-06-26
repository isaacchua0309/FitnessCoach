//
//  TodayCaloriesHero.swift
//  Fitness Coach
//
//  FitPilot AI — Dominant read-only calorie status for Today.
//

import SwiftUI

struct TodayCaloriesHero: View {
    let calories: CalorieSummary
    let coachSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
            Text(calories.isOverTarget ? FormaProductCopy.Today.caloriesAboveTarget : FormaProductCopy.Today.caloriesRemaining)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(displayRemainingCalories)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(calories.isOverTarget ? FormaTokens.Color.destructive : FormaTokens.Color.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("kcal")
                    .font(FormaTokens.Typography.sectionTitle.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }

            SwiftUI.ProgressView(value: min(calories.progress, 1))
                .tint(calories.isOverTarget ? FormaTokens.Color.destructive : FormaTokens.Color.accent)

            Text("\(calories.consumed) eaten · \(calories.target) target")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(coachSummary)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textLegal)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .accessibilityLabel("Coach guidance: \(coachSummary)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayRemainingCalories: Int {
        calories.isOverTarget ? calories.consumed - calories.target : calories.remaining
    }
}

#Preview {
    TodayCaloriesHero(
        calories: TodayPreviewData.state.calorieSummary,
        coachSummary: TodayPreviewData.state.coachingNote ?? FormaProductCopy.Today.defaultCoachNote
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
