//
//  TodayQuickActionsSection.swift
//  Fitness Coach
//
//  Forma — Inline quick log actions on Today (replaces floating FAB menu).
//

import SwiftUI

struct TodayQuickActionsSection: View {
    let menuItems: [TodayQuickActionMenuItem]
    let onSelect: (TodayQuickActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.QuickActions.sectionTitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FormaTokens.Spacing.sm) {
                    ForEach(menuItems) { item in
                        quickActionButton(item)
                    }
                }
                .padding(.trailing, FormaTokens.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func quickActionButton(_ item: TodayQuickActionMenuItem) -> some View {
        if item.isEnabled {
            Button {
                onSelect(item.kind)
            } label: {
                quickActionLabel(for: item.kind)
            }
            .buttonStyle(.bordered)
            .tint(FormaTokens.Color.accent)
            .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: item.kind))
            .accessibilityHint(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: item.kind))
        } else {
            quickActionLabel(for: item.kind)
                .padding(.horizontal, FormaTokens.Spacing.sm)
                .padding(.vertical, FormaTokens.Spacing.xs)
                .background(FormaTokens.Color.surfaceSubtle, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(FormaTokens.Color.border.opacity(0.55), lineWidth: 0.5)
                }
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .accessibilityLabel(FormaProductCopy.Today.QuickActions.title(for: item.kind))
                .accessibilityValue(FormaProductCopy.Today.QuickActions.scanFoodUnavailableNote)
        }
    }

    private func quickActionLabel(for kind: TodayQuickActionKind) -> some View {
        Label {
            Text(FormaProductCopy.Today.QuickActions.title(for: kind))
                .font(FormaTokens.Typography.caption.weight(.semibold))
        } icon: {
            Image(systemName: FormaProductCopy.Today.QuickActions.symbolName(for: kind))
                .font(.caption.weight(.semibold))
        }
        .labelStyle(.titleAndIcon)
    }
}

#Preview {
    TodayQuickActionsSection(
        menuItems: TodayQuickActionPolicy.menuItems(isScanFoodAvailable: false),
        onSelect: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
