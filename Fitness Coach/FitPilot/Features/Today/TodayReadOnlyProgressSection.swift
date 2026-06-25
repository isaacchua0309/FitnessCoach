//
//  TodayReadOnlyProgressSection.swift
//  Fitness Coach
//
//  FitPilot AI — Compact read-only macro and hydration progress.
//

import SwiftUI

struct TodayReadOnlyProgressSection: View {
    let macros: MacroSummary
    let water: WaterSummary

    @State private var showsMacroDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.itemSpacing) {
            TodaySectionLabel(title: "Progress")

            progressRow(
                title: "Protein",
                consumed: macros.protein.consumed,
                target: macros.protein.target,
                unit: "g",
                progress: macros.protein.progress
            )

            progressRow(
                title: "Water",
                consumed: Double(water.consumedMl),
                target: Double(water.targetMl),
                unit: "ml",
                progress: water.progress
            )

            if showsMacroDetail {
                progressRow(
                    title: "Carbs",
                    consumed: macros.carbs.consumed,
                    target: macros.carbs.target,
                    unit: "g",
                    progress: macros.carbs.progress
                )
                progressRow(
                    title: "Fat",
                    consumed: macros.fat.consumed,
                    target: macros.fat.target,
                    unit: "g",
                    progress: macros.fat.progress
                )
            }

            Button(showsMacroDetail ? "Hide carbs & fat" : "Show carbs & fat") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsMacroDetail.toggle()
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    private func progressRow(
        title: String,
        consumed: Double,
        target: Double,
        unit: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(formatValue(consumed)) / \(formatValue(target)) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            SwiftUI.ProgressView(value: min(progress, 1))
                .tint(Color.secondary.opacity(0.55))
        }
    }

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview {
    TodayReadOnlyProgressSection(
        macros: TodayPreviewData.state.macroSummary,
        water: TodayPreviewData.state.waterSummary
    )
    .padding()
}
