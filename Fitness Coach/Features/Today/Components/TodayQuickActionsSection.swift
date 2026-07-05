//
//  TodayQuickActionsSection.swift
//  Fitness Coach
//
//  Forma — Compact quick-action row on Today (meal, water, coach, plan).
//

import SwiftUI

struct TodayQuickActionsSection: View {
    let showsScanMeal: Bool
    let onLogMeal: () -> Void
    let onAddWater: () -> Void
    let onAskCoach: () -> Void
    let onViewPlan: () -> Void
    let onScanMeal: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: FormaTokens.Spacing.xs),
        GridItem(.flexible(), spacing: FormaTokens.Spacing.xs)
    ]

    var body: some View {
        let _ = themeManager.themeRevision

        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.QuickActions.sectionTitle)

            LazyVGrid(columns: columns, spacing: FormaTokens.Spacing.xs) {
                quickActionButton(
                    title: FormaProductCopy.Today.QuickActions.title(for: .logMeal),
                    symbolName: FormaProductCopy.Today.QuickActions.symbolName(for: .logMeal),
                    isPrimary: true,
                    action: onLogMeal,
                    accessibilityHint: FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .logMeal)
                )

                quickActionButton(
                    title: FormaProductCopy.Today.QuickActions.addWater,
                    symbolName: "drop.fill",
                    isPrimary: false,
                    action: onAddWater,
                    accessibilityHint: FormaProductCopy.Today.QuickActions.addWaterAccessibilityHint
                )

                quickActionButton(
                    title: FormaProductCopy.Today.QuickActions.askCoach,
                    symbolName: "bubble.left.and.bubble.right.fill",
                    isPrimary: false,
                    action: onAskCoach,
                    accessibilityHint: FormaProductCopy.Today.QuickActions.askCoachAccessibilityHint
                )

                quickActionButton(
                    title: FormaProductCopy.Today.QuickActions.viewPlan,
                    symbolName: "list.bullet.clipboard.fill",
                    isPrimary: false,
                    action: onViewPlan,
                    accessibilityHint: FormaProductCopy.Today.QuickActions.viewPlanAccessibilityHint
                )
            }

            if showsScanMeal {
                Button(action: onScanMeal) {
                    HStack(spacing: FormaTokens.Spacing.xs) {
                        Image(systemName: FormaProductCopy.Today.QuickActions.symbolName(for: .scanFood))
                            .font(.caption.weight(.semibold))
                        Text(FormaProductCopy.Today.QuickActions.title(for: .scanFood))
                            .font(FormaTokens.Typography.caption.weight(.semibold))
                    }
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: .scanFood))
                .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .scanFood))
            }
        }
        .accessibilityElement(children: .contain)
        .todayLiveTheme()
    }

    private func quickActionButton(
        title: String,
        symbolName: String,
        isPrimary: Bool,
        action: @escaping () -> Void,
        accessibilityHint: String
    ) -> some View {
        Button(action: action) {
            VStack(spacing: FormaTokens.Spacing.xs) {
                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isPrimary ? theme.buttonText : theme.accent)

                Text(title)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(isPrimary ? theme.buttonText : theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .background(
                isPrimary
                    ? theme.buttonBackground
                    : FormaCardChrome.background(.bordered)
            )
            .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous))
        }
        .buttonStyle(TodaySurfaceCardPressStyle())
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }
}

#Preview {
    TodayQuickActionsSection(
        showsScanMeal: true,
        onLogMeal: {},
        onAddWater: {},
        onAskCoach: {},
        onViewPlan: {},
        onScanMeal: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large text") {
    TodayQuickActionsSection(
        showsScanMeal: false,
        onLogMeal: {},
        onAddWater: {},
        onAskCoach: {},
        onViewPlan: {},
        onScanMeal: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .dynamicTypeSize(.accessibility2)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
