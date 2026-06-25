//
//  TodaySummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Primary daily summary: calories, macros, and one-line insight.
//

import SwiftUI

struct TodaySummaryCard: View {
    let calories: CalorieSummary
    let macros: MacroSummary
    let water: WaterSummary
    let coachingNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(calories.isOverTarget ? "Over target" : "Calories remaining")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(displayRemainingCalories)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(calories.isOverTarget ? .red : .primary)
                    Text("kcal")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text("\(calories.consumed) consumed · \(calories.target) target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SwiftUI.ProgressView(value: min(calories.progress, 1))
                .tint(calories.isOverTarget ? .red : .blue)

            HStack(spacing: 12) {
                compactMacroChip(
                    label: "Protein",
                    consumed: macros.protein.consumed,
                    target: macros.protein.target,
                    color: .orange
                )
                compactMacroChip(
                    label: "Water",
                    consumed: Double(water.consumedMl),
                    target: Double(water.targetMl),
                    color: .cyan,
                    unit: "ml"
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                compactMacroLine(name: "Protein", progress: macros.protein)
                compactMacroLine(name: "Carbs", progress: macros.carbs)
                compactMacroLine(name: "Fat", progress: macros.fat)
            }

            if let coachingNote {
                Label(coachingNote, systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
    }

    private var displayRemainingCalories: Int {
        calories.isOverTarget ? calories.consumed - calories.target : calories.remaining
    }

    private func compactMacroChip(
        label: String,
        consumed: Double,
        target: Double,
        color: Color,
        unit: String = "g"
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(formatValue(consumed)) / \(formatValue(target)) \(unit)")
                .font(.caption.weight(.medium))
            SwiftUI.ProgressView(value: target > 0 ? min(consumed / target, 1) : 0)
                .tint(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func compactMacroLine(name: String, progress: MacroProgress) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption.weight(.medium))
                .frame(width: 52, alignment: .leading)
            SwiftUI.ProgressView(value: progress.progress)
                .tint(.secondary)
            Text("\(formatValue(progress.consumed))/\(formatValue(progress.target))g")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
    }

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview {
    TodaySummaryCard(
        calories: TodayPreviewData.state.calorieSummary,
        macros: TodayPreviewData.state.macroSummary,
        water: TodayPreviewData.state.waterSummary,
        coachingNote: TodayPreviewData.state.coachingNote
    )
    .padding()
}
