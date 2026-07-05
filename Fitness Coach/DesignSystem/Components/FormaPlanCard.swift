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

    var body: some View {
        Group {
            if multilineValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(theme.secondaryText)
                    Text(value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(theme.secondaryText)
                        .frame(
                            width: SettingsChromeAccessibility.detailLabelColumnWidth,
                            alignment: .leading
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Text(value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .padding(.vertical, 2)
    }
}

struct FormaPlanRowDivider: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Divider()
            .overlay(theme.inputBorder)
    }
}
