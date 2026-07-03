//
//  TodayQuickActionsSection.swift
//  Fitness Coach
//
//  Forma — Primary fast-log surface on Today (meal + water).
//

import SwiftUI

struct TodayQuickActionsSection: View {
    let showsScanMeal: Bool
    let waterPresetAmountsMl: [Int]
    let onLogMeal: () -> Void
    let onScanMeal: () -> Void
    let onAddWater: (Int) -> Void

    @State private var isWaterExpanded = false

    private let primaryActionMinHeight: CGFloat = 92
    private let iconSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.QuickActions.sectionTitle)

            VStack(spacing: FormaTokens.Spacing.sm) {
                HStack(spacing: FormaTokens.Spacing.sm) {
                    primaryActionCard(
                        title: FormaProductCopy.Today.QuickActions.title(for: .logMeal),
                        symbolName: FormaProductCopy.Today.QuickActions.symbolName(for: .logMeal),
                        isEmphasized: false,
                        action: onLogMeal
                    )
                    .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: .logMeal))
                    .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .logMeal))

                    primaryActionCard(
                        title: FormaProductCopy.Today.QuickActions.title(for: .addWater),
                        symbolName: FormaProductCopy.Today.QuickActions.symbolName(for: .addWater),
                        isEmphasized: isWaterExpanded,
                        action: toggleWaterExpansion
                    )
                    .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: .addWater))
                    .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .addWater))
                    .accessibilityValue(isWaterExpanded ? "Expanded" : "Collapsed")
                }

                if isWaterExpanded {
                    waterAmountsRow
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if showsScanMeal {
                    scanMealSecondaryAction
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isWaterExpanded)
        .accessibilityElement(children: .contain)
    }

    private var waterAmountsRow: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(waterPresetAmountsMl, id: \.self) { amountMl in
                Button {
                    onAddWater(amountMl)
                    isWaterExpanded = false
                } label: {
                    Text(FormaProductCopy.Today.QuickActions.waterAmountLabel(amountMl))
                        .font(FormaTokens.Typography.bodyMedium.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FormaTokens.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                                .fill(FormaTokens.Theme.softBackground)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                                .stroke(FormaTokens.Theme.borderTint.opacity(0.3), lineWidth: 0.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FormaProductCopy.Today.QuickActions.waterAmountAccessibilityLabel(amountMl))
            }
        }
    }

    private var scanMealSecondaryAction: some View {
        Button(action: onScanMeal) {
            HStack(spacing: FormaTokens.Spacing.sm) {
                Image(systemName: FormaProductCopy.Today.QuickActions.symbolName(for: .scanFood))
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(FormaTokens.Theme.primary)
                    .frame(width: 28)

                Text(FormaProductCopy.Today.QuickActions.title(for: .scanFood))
                    .font(FormaTokens.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: FormaTokens.Layout.minTouchTarget)
            .background(FormaCardChrome.background(.bordered))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: .scanFood))
        .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .scanFood))
    }

    private func toggleWaterExpansion() {
        isWaterExpanded.toggle()
    }

    private func primaryActionCard(
        title: String,
        symbolName: String,
        isEmphasized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: FormaTokens.Spacing.sm) {
                Image(systemName: symbolName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(FormaTokens.Theme.primary)

                Text(title)
                    .font(FormaTokens.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: primaryActionMinHeight)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, FormaTokens.Spacing.md)
            .background(primaryCardBackground(isEmphasized: isEmphasized))
            .overlay {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(
                        isEmphasized
                            ? FormaTokens.Theme.primary.opacity(0.4)
                            : FormaTokens.Theme.borderTint.opacity(0.22),
                        lineWidth: isEmphasized ? 1.5 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func primaryCardBackground(isEmphasized: Bool) -> some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(isEmphasized ? FormaTokens.Theme.softBackground : FormaTokens.Color.surface)
    }
}

#Preview {
    TodayQuickActionsSection(
        showsScanMeal: true,
        waterPresetAmountsMl: [250, 500, 750, 1_000],
        onLogMeal: {},
        onScanMeal: {},
        onAddWater: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Water expanded") {
    TodayQuickActionsSection(
        showsScanMeal: false,
        waterPresetAmountsMl: [250, 500, 750, 1_000],
        onLogMeal: {},
        onScanMeal: {},
        onAddWater: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
