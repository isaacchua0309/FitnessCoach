//
//  TodayMacroBalanceCard.swift
//  Fitness Coach
//
//  Forma — Macro Balance card with protein, carbs, and fat progress.
//

import SwiftUI

struct TodayMacroBalanceCard: View {
    let macros: MacroSummary

    private var display: TodayMacroBalanceCardDisplayModel {
        TodayMacroBalanceFormatting.displayModel(for: macros)
    }

    var body: some View {
        TodayMacroBalanceMetricsCard {
            VStack(alignment: .leading, spacing: 0) {
                macroRow(display.protein)

                FitPilotPlanRowDivider()

                macroRow(display.carbs)

                FitPilotPlanRowDivider()

                macroRow(display.fat)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(display.accessibilitySummary)
    }

    @ViewBuilder
    private func macroRow(_ row: TodayMacroBalanceRowDisplayModel) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(row.name)
                    .font(row.isProteinPriority
                        ? FormaTokens.Typography.sectionSubtitle.weight(.semibold)
                        : FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(
                        row.isProteinPriority
                            ? FormaTokens.Color.textPrimary
                            : FormaTokens.Color.textSecondary
                    )
                    .layoutPriority(1)
                    .lineLimit(1)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(row.ratioText)
                    .font(row.isProteinPriority
                        ? FormaTokens.Typography.sectionSubtitle
                        : FormaTokens.Typography.caption)
                    .foregroundStyle(
                        row.isProteinPriority
                            ? FormaTokens.Color.textPrimary
                            : FormaTokens.Color.textSecondary
                    )
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .monospacedDigit()
            }

            TodayMetricProgressBar(
                progress: row.barProgress,
                subdued: !row.isProteinPriority
            )

            Text(row.remainingText)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(remainingTextColor(for: row.displayState))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, TodayLayout.compactSpacing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
    }

    private func remainingTextColor(for state: TodayMacroBalanceDisplayState) -> Color {
        switch state {
        case .overTarget, .missingTarget:
            FormaTokens.Color.textTertiary
        case .nearTarget:
            FormaTokens.Color.textSecondary
        case .belowTarget:
            FormaTokens.Color.textSecondary
        }
    }
}

/// Accent-leading card chrome for the protein-prioritized macro balance block.
private struct TodayMacroBalanceMetricsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(macroBalanceCardBackground())
    }
}

private func macroBalanceCardBackground() -> some View {
    RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
        .fill(FormaTokens.Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            FormaTokens.Color.accent.opacity(0.22),
                            FormaTokens.Color.border
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(FormaTokens.Color.accent.opacity(0.55))
                .frame(width: 3)
                .padding(.vertical, FormaTokens.Spacing.sm)
                .padding(.leading, 1)
        }
}

#Preview("Macro balance") {
    TodayMacroBalanceCard(macros: TodayPreviewData.state.macroBalance.macroSummary)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Below target") {
    TodayMacroBalanceCard(
        macros: MacroSummary(
            protein: MacroProgress(consumed: 92, target: 180, remaining: 88, progress: 0.51),
            carbs: MacroProgress(consumed: 120, target: 220, remaining: 100, progress: 0.55),
            fat: MacroProgress(consumed: 40, target: 65, remaining: 25, progress: 0.62)
        )
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
