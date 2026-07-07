//
//  FormaPlanCard.swift
//  Fitness Coach
//
//  Forma — Accent-bordered section card for dashboards and settings.
//

import SwiftUI

struct FormaPlanCard<Content: View>: View {
    var compact: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        MainTabCard(compact: compact) {
            content
        }
    }
}

struct FormaPlanDisplayRow: View {
    let label: String
    let value: String
    var multilineValue = false

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if usesStackedLayout {
                stackedLayout
            } else if multilineValue {
                stackedLayout
            } else {
                inlineLayout
            }
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .padding(.vertical, 2)
    }

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
    }

    private var inlineLayout: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: 96, alignment: .leading)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)
                .textSelection(.enabled)
        }
    }
}

struct FormaPlanRowDivider: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Divider()
            .overlay(theme.inputBorder)
    }
}
