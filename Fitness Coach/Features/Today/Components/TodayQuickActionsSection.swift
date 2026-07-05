//
//  TodayQuickActionsSection.swift
//  Fitness Coach
//
//  Forma — Primary fast-log surface on Today (meal + optional scan).
//

import SwiftUI

struct TodayQuickActionsSection: View {
    let showsScanMeal: Bool
    let onLogMeal: () -> Void
    let onScanMeal: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private let primaryActionMinHeight: CGFloat = 92
    private let iconSize: CGFloat = 28

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.QuickActions.sectionTitle)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                primaryActionCard(
                    title: FormaProductCopy.Today.QuickActions.title(for: .logMeal),
                    symbolName: FormaProductCopy.Today.QuickActions.symbolName(for: .logMeal),
                    action: onLogMeal
                )
                .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: .logMeal))
                .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .logMeal))

                Text(FormaProductCopy.Today.QuickActions.logMealMicrocopy)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)

                if showsScanMeal {
                    scanMealSecondaryAction
                        .padding(.top, FormaTokens.Spacing.xs)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .todayLiveTheme()
    }

    private var scanMealSecondaryAction: some View {
        Button(action: onScanMeal) {
            HStack(spacing: FormaTokens.Spacing.sm) {
                Image(systemName: FormaProductCopy.Today.QuickActions.symbolName(for: .scanFood))
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)
                    .frame(width: 28)

                Text(FormaProductCopy.Today.QuickActions.title(for: .scanFood))
                    .font(FormaTokens.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.tertiaryText)
            }
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: FormaTokens.Layout.minTouchTarget)
            .background(FormaCardChrome.background(.bordered))
        }
        .buttonStyle(TodayBorderedRowPressStyle())
        .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: .scanFood))
        .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .scanFood))
    }

    private func primaryActionCard(
        title: String,
        symbolName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: FormaTokens.Spacing.sm) {
                Image(systemName: symbolName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)

                Text(title)
                    .font(FormaTokens.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: primaryActionMinHeight)
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.md)
            .background(FormaCardChrome.background(.accentLeading))
        }
        .buttonStyle(TodaySurfaceCardPressStyle())
    }
}

#Preview {
    TodayQuickActionsSection(
        showsScanMeal: true,
        onLogMeal: {},
        onScanMeal: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
