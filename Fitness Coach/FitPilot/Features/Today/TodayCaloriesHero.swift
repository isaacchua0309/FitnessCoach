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
        VStack(alignment: .leading, spacing: 14) {
            Text(calories.isOverTarget ? "Over target" : "Calories remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(displayRemainingCalories)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(calories.isOverTarget ? Color.red : Color.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("kcal")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            SwiftUI.ProgressView(value: min(calories.progress, 1))
                .tint(calories.isOverTarget ? .red : Color.accentColor)

            Text("\(calories.consumed) eaten · \(calories.target) target")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(coachSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
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
        coachSummary: TodayPreviewData.state.coachingNote ?? "On track."
    )
    .padding()
}
