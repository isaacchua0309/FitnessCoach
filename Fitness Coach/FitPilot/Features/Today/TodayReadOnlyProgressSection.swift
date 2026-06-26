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

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    progressRow(
                        title: "Protein",
                        consumed: macros.protein.consumed,
                        target: macros.protein.target,
                        unit: "g",
                        progress: macros.protein.progress
                    )

                    FitPilotPlanRowDivider()

                    progressRow(
                        title: "Water",
                        consumed: Double(water.consumedMl),
                        target: Double(water.targetMl),
                        unit: "ml",
                        progress: water.progress
                    )

                    if showsMacroDetail {
                        FitPilotPlanRowDivider()
                        progressRow(
                            title: "Carbs",
                            consumed: macros.carbs.consumed,
                            target: macros.carbs.target,
                            unit: "g",
                            progress: macros.carbs.progress
                        )
                        FitPilotPlanRowDivider()
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
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .padding(.top, 2)
                }
            }
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
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                Spacer()
                Text("\(formatValue(consumed)) / \(formatValue(target)) \(unit)")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }
            SwiftUI.ProgressView(value: min(progress, 1))
                .tint(FormaTokens.Color.accent)
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
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
