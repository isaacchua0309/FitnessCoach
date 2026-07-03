//
//  TodayWaterQuickLogSection.swift
//  Fitness Coach
//
//  Forma — Inline one-tap water logging with live progress on Today.
//

import SwiftUI

struct TodayWaterQuickLogSection: View {
    let water: WaterSummary
    let presetAmountsMl: [Int]
    let onAddWater: (Int) -> Bool

    @State private var pendingAddedMl = 0
    @State private var highlightedAmountMl: Int?

    private var displayedWater: WaterSummary {
        guard pendingAddedMl > 0 else { return water }
        let consumedMl = water.consumedMl + pendingAddedMl
        let targetMl = max(water.targetMl, 1)
        return WaterSummary(
            consumedMl: consumedMl,
            targetMl: water.targetMl,
            remainingMl: consumedMl >= water.targetMl ? 0 : water.targetMl - consumedMl,
            progress: min(Double(consumedMl) / Double(targetMl), 1)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.Water.sectionTitle)

            TodayActionCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    headerRow

                    TodayMetricProgressBar(
                        progress: displayedWater.progress,
                        subdued: false
                    )
                    .animation(.easeOut(duration: 0.28), value: displayedWater.progress)

                    Text(remainingText)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .monospacedDigit()
                        .animation(.easeOut(duration: 0.2), value: displayedWater.consumedMl)

                    quickAddButtons
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
        .onChange(of: water.consumedMl) { _, _ in
            pendingAddedMl = 0
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: FormaProductCopy.Today.QuickActions.symbolName(for: .addWater))
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(FormaTokens.Theme.primary)

            Text(FormaProductCopy.Today.MacroBalance.water)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Text(TodayTargetsFormatter.waterProgress(
                consumedMl: displayedWater.consumedMl,
                targetMl: displayedWater.targetMl
            ))
            .font(FormaTokens.Typography.bodyMedium.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.2), value: displayedWater.consumedMl)
        }
    }

    private var remainingText: String {
        let state = TodayNutritionProgressFormatting.displayState(
            consumed: Double(displayedWater.consumedMl),
            target: Double(displayedWater.targetMl),
            remaining: Double(displayedWater.remainingMl)
        )
        return TodayNutritionProgressFormatting.waterRemainingText(
            summary: displayedWater,
            state: state
        )
    }

    private var quickAddButtons: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(presetAmountsMl, id: \.self) { amountMl in
                Button {
                    logWater(amountMl: amountMl)
                } label: {
                    Text(FormaProductCopy.Today.Water.quickAddLabel(amountMl))
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(
                            highlightedAmountMl == amountMl
                                ? FormaTokens.Theme.textOnAccent
                                : FormaTokens.Theme.primary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FormaTokens.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                                .fill(
                                    highlightedAmountMl == amountMl
                                        ? FormaTokens.Theme.primary
                                        : FormaTokens.Theme.softBackground
                                )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                                .stroke(FormaTokens.Theme.borderTint.opacity(0.28), lineWidth: 0.5)
                        }
                        .scaleEffect(highlightedAmountMl == amountMl ? 0.96 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FormaProductCopy.Today.QuickActions.waterAmountAccessibilityLabel(amountMl))
            }
        }
        .padding(.top, FormaTokens.Spacing.xs)
    }

    private func logWater(amountMl: Int) {
        pendingAddedMl += amountMl
        highlightedAmountMl = amountMl

        let succeeded = onAddWater(amountMl)
        if !succeeded {
            pendingAddedMl = max(pendingAddedMl - amountMl, 0)
            highlightedAmountMl = nil
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if highlightedAmountMl == amountMl {
                highlightedAmountMl = nil
            }
        }
    }
}

#Preview {
    TodayWaterQuickLogSection(
        water: WaterSummary(consumedMl: 1_200, targetMl: 3_500, remainingMl: 2_300, progress: 0.34),
        presetAmountsMl: [250, 500, 750, 1_000],
        onAddWater: { _ in true }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
