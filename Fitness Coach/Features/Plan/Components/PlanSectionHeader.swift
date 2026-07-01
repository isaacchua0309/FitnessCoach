//
//  PlanSectionHeader.swift
//  Fitness Coach
//
//  Forma — Section title + optional action that wraps on narrow widths.
//

import SwiftUI

struct PlanSectionHeader: View {
    let title: String
    var actionTitle: String?
    var actionAccessibilityHint: String?
    var action: (() -> Void)?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            headerRow
            headerStack
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            FormaSectionLabel(title: title)
            Spacer(minLength: 8)
            actionButton
        }
    }

    private var headerStack: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            FormaSectionLabel(title: title)
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle, let action {
            Button(actionTitle, action: action)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.accent)
                .buttonStyle(.plain)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                .multilineTextAlignment(.leading)
                .accessibilityLabel(actionTitle)
                .accessibilityHint(actionAccessibilityHint ?? "")
        }
    }
}
