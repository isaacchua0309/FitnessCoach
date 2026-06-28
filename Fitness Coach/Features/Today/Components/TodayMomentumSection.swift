//
//  TodayMomentumSection.swift
//  Fitness Coach
//
//  Forma — Today's Momentum: logging streak and weekly consistency.
//

import SwiftUI

struct TodayMomentumSection: View {
    let momentum: TodayMomentumState

    private var display: TodayMomentumSectionDisplayModel {
        TodayMomentumSectionFormatting.displayModel(for: momentum)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.Momentum.sectionTitle)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    momentumLine(display.loggingStreakLine)

                    FitPilotPlanRowDivider()

                    momentumLine(display.weekProgressLine)

                    ForEach(Array(display.optionalStreakLines.enumerated()), id: \.offset) { index, line in
                        FitPilotPlanRowDivider()
                        momentumLine(line)
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(display.accessibilitySummary)
    }

    private func momentumLine(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(text)
    }
}

#Preview("Active streak") {
    TodayMomentumSection(
        momentum: TodayMomentumState(
            streaks: StreakSummary(
                loggingStreak: 21,
                proteinStreak: 5,
                hydrationStreak: 3,
                workoutStreak: 0
            ),
            weekLoggedDays: 5
        )
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("New user") {
    TodayMomentumSection(
        momentum: TodayMomentumState(
            streaks: StreakSummary(
                loggingStreak: 0,
                proteinStreak: 0,
                hydrationStreak: 0,
                workoutStreak: 0
            ),
            weekLoggedDays: 0
        )
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
