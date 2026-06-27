//
//  TodayReadOnlyProgressSection.swift
//  Fitness Coach
//
//  Forma — Today's Targets: exact macro and hydration progress.
//

import SwiftUI

struct TodayReadOnlyProgressSection: View {
    let macros: MacroSummary
    let water: WaterSummary

    @State private var showsMacroDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodayMutedSectionLabel(title: FormaProductCopy.Today.targetsSectionTitle)

            TodayMetricsCard {
                VStack(alignment: .leading, spacing: 0) {
                    targetRow(
                        title: "Protein",
                        progressText: TodayTargetsFormatter.macroProgress(
                            consumed: macros.protein.consumed,
                            target: macros.protein.target
                        ),
                        progress: macros.protein.progress
                    )

                    FitPilotPlanRowDivider()

                    targetRow(
                        title: "Water",
                        progressText: TodayTargetsFormatter.waterProgress(
                            consumedMl: water.consumedMl,
                            targetMl: water.targetMl
                        ),
                        progress: water.progress
                    )

                    if showsMacroDetail {
                        FitPilotPlanRowDivider()

                        targetRow(
                            title: "Carbs",
                            progressText: TodayTargetsFormatter.macroProgress(
                                consumed: macros.carbs.consumed,
                                target: macros.carbs.target
                            ),
                            progress: macros.carbs.progress
                        )

                        FitPilotPlanRowDivider()

                        targetRow(
                            title: "Fat",
                            progressText: TodayTargetsFormatter.macroProgress(
                                consumed: macros.fat.consumed,
                                target: macros.fat.target
                            ),
                            progress: macros.fat.progress
                        )
                    }

                    Button(
                        showsMacroDetail
                            ? FormaProductCopy.Today.hideCarbsAndFat
                            : FormaProductCopy.Today.showCarbsAndFat
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsMacroDetail.toggle()
                        }
                    }
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .padding(.top, FormaTokens.Spacing.xs)
                    .accessibilityLabel(
                        showsMacroDetail
                            ? FormaProductCopy.Today.hideCarbsAndFat
                            : FormaProductCopy.Today.showCarbsAndFat
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func targetRow(
        title: String,
        progressText: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(title)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .layoutPriority(1)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(progressText)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .monospacedDigit()
                    .layoutPriority(0)
            }

            TodayMetricProgressBar(progress: progress)
        }
        .padding(.vertical, TodayLayout.compactSpacing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(progressText), \(progressAccessibilityValue(progress))")
    }

    private func progressAccessibilityValue(_ progress: Double) -> String {
        "\(Int((min(max(progress, 0), 1) * 100).rounded())) percent of target"
    }
}

#Preview("Today's targets") {
    TodayReadOnlyProgressSection(
        macros: TodayPreviewData.state.macroSummary,
        water: TodayPreviewData.state.waterSummary
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Small width") {
    TodayReadOnlyProgressSection(
        macros: MacroSummary(
            protein: MacroProgress(consumed: 31, target: 180, remaining: 149, progress: 0.17),
            carbs: MacroProgress(consumed: 55, target: 160, remaining: 105, progress: 0.34),
            fat: MacroProgress(consumed: 19.5, target: 60, remaining: 40.5, progress: 0.33)
        ),
        water: WaterSummary(consumedMl: 500, targetMl: 3_150, remainingMl: 2_650, progress: 0.16)
    )
    .frame(width: 320)
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
