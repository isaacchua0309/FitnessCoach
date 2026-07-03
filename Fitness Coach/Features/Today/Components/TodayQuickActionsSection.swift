//
//  TodayQuickActionsSection.swift
//  Fitness Coach
//
//  Forma — Inline quick log actions on Today.
//

import SwiftUI

struct TodayQuickActionsSection: View {
    let menuItems: [TodayQuickActionMenuItem]
    let onSelect: (TodayQuickActionKind) -> Void

    @ScaledMetric(relativeTo: .body) private var primaryIconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var secondaryIconSize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) private var primaryTileMinWidth: CGFloat = 72
    @ScaledMetric(relativeTo: .caption2) private var secondaryTileMinWidth: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.QuickActions.sectionTitle)

            ViewThatFits(in: .horizontal) {
                actionRow
                ScrollView(.horizontal, showsIndicators: false) {
                    actionRow
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var actionRow: some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            ForEach(menuItems) { item in
                quickActionButton(item)
            }
        }
        .padding(.trailing, FormaTokens.Spacing.xs)
    }

    @ViewBuilder
    private func quickActionButton(_ item: TodayQuickActionMenuItem) -> some View {
        if item.isEnabled {
            Button {
                onSelect(item.kind)
            } label: {
                quickActionTile(for: item)
            }
            .modifier(QuickActionButtonModifier(presentation: item.presentation))
            .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: item.kind))
            .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: item.kind))
        } else {
            quickActionTile(for: item)
                .frame(minWidth: tileMinWidth(for: item), minHeight: FormaTokens.Layout.minTouchTarget)
                .background(FormaTokens.Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: FormaTokens.Radius.button))
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.button)
                        .stroke(FormaTokens.Color.border.opacity(0.55), lineWidth: 0.5)
                }
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: item.kind))
                .accessibilityValue(FormaProductCopy.Today.QuickActions.scanFoodUnavailableNote)
        }
    }

    private func quickActionTile(for item: TodayQuickActionMenuItem) -> some View {
        let isPrimary = item.presentation == .primary
        let titleFont: Font = isPrimary
            ? FormaTokens.Typography.caption.weight(.semibold)
            : FormaTokens.Typography.caption2.weight(.semibold)
        let iconSize = isPrimary ? primaryIconSize : secondaryIconSize

        return VStack(spacing: TodayLayout.compactSpacing) {
            Image(systemName: FormaProductCopy.Today.QuickActions.symbolName(for: item.kind))
                .font(.system(size: iconSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(FormaProductCopy.Today.QuickActions.title(for: item.kind))
                .font(titleFont)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(minWidth: tileMinWidth(for: item), minHeight: FormaTokens.Layout.minTouchTarget)
        .padding(.horizontal, isPrimary ? FormaTokens.Spacing.sm : FormaTokens.Spacing.xs)
        .padding(.vertical, FormaTokens.Spacing.xs)
    }

    private func tileMinWidth(for item: TodayQuickActionMenuItem) -> CGFloat {
        item.presentation == .primary ? primaryTileMinWidth : secondaryTileMinWidth
    }
}

private struct QuickActionButtonModifier: ViewModifier {
    let presentation: TodayQuickActionPresentation

    func body(content: Content) -> some View {
        switch presentation {
        case .primary:
            content
                .buttonStyle(.borderedProminent)
                .tint(FormaTokens.Theme.primary)
        case .secondary:
            content
                .buttonStyle(.bordered)
                .tint(FormaTokens.Theme.primary)
        }
    }
}

#Preview {
    TodayQuickActionsSection(
        menuItems: TodayQuickActionPolicy.menuItems(isScanFoodAvailable: true),
        onSelect: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Scan unavailable") {
    TodayQuickActionsSection(
        menuItems: TodayQuickActionPolicy.menuItems(isScanFoodAvailable: false),
        onSelect: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large text") {
    TodayQuickActionsSection(
        menuItems: TodayQuickActionPolicy.menuItems(isScanFoodAvailable: true),
        onSelect: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .dynamicTypeSize(.accessibility2)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
