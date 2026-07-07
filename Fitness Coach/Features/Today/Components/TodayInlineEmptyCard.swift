//
//  TodayInlineEmptyCard.swift
//  Fitness Coach
//
//  Forma — Encouraging inline empty card for Today sections.
//

import SwiftUI

struct TodayInlineEmptyCard: View {
    let copy: TodayEmptyStateCopy
    let onAction: (() -> Void)?

    @Environment(\.theme) private var theme

    var body: some View {
        MainTabCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(copy.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(copy.body)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle = copy.actionTitle, let onAction {
                    FormaQuickActionChip(
                        title: actionTitle,
                        action: onAction,
                        accessibilityHint: copy.accessibilityHint
                    )
                    .padding(.top, FormaTokens.Spacing.xs)
                }
            }
            .padding(.vertical, FormaTokens.Spacing.xs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel([copy.title, copy.body, copy.actionTitle].compactMap { $0 }.joined(separator: ". "))
    }
}

#Preview {
    TodayInlineEmptyCard(
        copy: TodayEmptyStateFormatting.copy(for: .newProfileNoMeals),
        onAction: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
