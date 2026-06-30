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

    var body: some View {
        FormaPlanCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(copy.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(copy.body)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
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
