//
//  MacroSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Macro and calorie summary card.
//

import SwiftUI

struct MacroSummaryCard: View {
    let summary: MacroSummary
    let calories: CalorieSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Nutrition", systemImage: "chart.pie")
                    .font(.headline)
                Spacer()
                Text("\(calories.consumed) / \(calories.target) kcal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(calories.isOverTarget ? .red : .primary)
            }

            ProgressView(value: calories.progress)
                .tint(calories.isOverTarget ? .red : .blue)

            Text("\(calories.remaining) kcal remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            MacroProgressRow(name: "Protein", progress: summary.protein, unit: "g")
            MacroProgressRow(name: "Carbs", progress: summary.carbs, unit: "g")
            MacroProgressRow(name: "Fat", progress: summary.fat, unit: "g")
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    MacroSummaryCard(
        summary: TodayPreviewData.state.macroSummary,
        calories: TodayPreviewData.state.calorieSummary
    )
    .padding()
}
