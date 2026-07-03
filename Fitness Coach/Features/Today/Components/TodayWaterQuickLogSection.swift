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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pendingAddedMl = 0
    @State private var highlightedAmountMl: Int?
    @State private var tapLockedUntil = Date.distantPast

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

    private var isTapLocked: Bool {
        Date() < tapLockedUntil
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.32)
    }

    private var valueAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.22)
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
                    .animation(progressAnimation, value: displayedWater.progress)

                    Text(remainingText)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .monospacedDigit()
                        .animation(valueAnimation, value: displayedWater.consumedMl)

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
            .modifier(WaterValueTransitionModifier(reduceMotion: reduceMotion))
            .animation(valueAnimation, value: displayedWater.consumedMl)
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
                                .stroke(
                                    highlightedAmountMl == amountMl
                                        ? FormaTokens.Theme.primary.opacity(0.5)
                                        : FormaTokens.Theme.borderTint.opacity(0.28),
                                    lineWidth: highlightedAmountMl == amountMl ? 1 : 0.5
                                )
                        }
                }
                .buttonStyle(
                    TodayWaterQuickAddButtonStyle(
                        isSelected: highlightedAmountMl == amountMl,
                        reduceMotion: reduceMotion
                    )
                )
                .disabled(isTapLocked)
                .opacity(isTapLocked ? 0.72 : 1)
                .accessibilityLabel(FormaProductCopy.Today.QuickActions.waterAmountAccessibilityLabel(amountMl))
            }
        }
        .padding(.top, FormaTokens.Spacing.xs)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isTapLocked)
    }

    private func logWater(amountMl: Int) {
        guard !isTapLocked else { return }

        lockTapsBriefly()
        pendingAddedMl += amountMl
        highlightedAmountMl = amountMl

        let succeeded = onAddWater(amountMl)
        if !succeeded {
            pendingAddedMl = max(pendingAddedMl - amountMl, 0)
            highlightedAmountMl = nil
            tapLockedUntil = .distantPast
            return
        }

        clearHighlightAfterDelay(for: amountMl)
    }

    private func lockTapsBriefly() {
        tapLockedUntil = Date().addingTimeInterval(FormaProductCopy.Today.Water.tapDebounceSeconds)
    }

    private func clearHighlightAfterDelay(for amountMl: Int) {
        let delayNanoseconds: UInt64 = reduceMotion ? 80_000_000 : 220_000_000
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            if highlightedAmountMl == amountMl {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    highlightedAmountMl = nil
                }
            }
        }
    }
}

private struct WaterValueTransitionModifier: ViewModifier {
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.contentTransition(.numericText())
        }
    }
}

private struct TodayWaterQuickAddButtonStyle: ButtonStyle {
    let isSelected: Bool
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard !reduceMotion else { return 1 }
        if isPressed { return 0.94 }
        if isSelected { return 0.97 }
        return 1
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
