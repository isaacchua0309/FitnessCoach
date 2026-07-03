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

    private let primaryActionMinHeight: CGFloat = 92
    private let iconSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.QuickActions.sectionTitle)

            VStack(spacing: FormaTokens.Spacing.sm) {
                primaryActionCard(
                    title: FormaProductCopy.Today.QuickActions.title(for: .logMeal),
                    symbolName: FormaProductCopy.Today.QuickActions.symbolName(for: .logMeal),
                    action: onLogMeal
                )
                .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: .logMeal))
                .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .logMeal))

                if showsScanMeal {
                    scanMealSecondaryAction
                }
            }
        }
        .accessibilityElement(children: .contain)
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
            .background(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .fill(FormaTokens.Color.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(FormaTokens.Theme.borderTint.opacity(0.22), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
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
