//
//  FormaInlineEmptyState.swift
//  Fitness Coach
//
//  Forma — Compact title / body / optional CTA for in-card empty states.
//

import SwiftUI

struct FormaInlineEmptyState: View {
    var title: String?
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var actionAccessibilityHint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            if let title {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(title == nil ? FormaTokens.Color.textPrimary : FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                FormaQuickActionChip(
                    title: actionTitle,
                    action: action,
                    accessibilityHint: actionAccessibilityHint
                )
                .padding(.top, title == nil ? 0 : FormaTokens.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Quick action chip

struct FormaQuickActionChip: View {
    let title: String
    let action: () -> Void
    var accessibilityHint: String?

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(FormaTokens.Color.accent)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .accessibilityHint(accessibilityHint ?? "")
    }
}
