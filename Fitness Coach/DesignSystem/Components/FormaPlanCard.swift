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

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let _ = themeManager.themeRevision
        return content
            .padding(.horizontal, compact ? FormaTokens.Spacing.sm : FormaTokens.Spacing.md)
            .padding(.vertical, compact ? FormaTokens.Spacing.xs : FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FormaCardChrome.background(.surface))
    }
}

struct FormaPlanDisplayRow: View {
    let label: String
    let value: String
    var multilineValue = false

    @Environment(\.formaColors) private var colors

    var body: some View {
        Group {
            if multilineValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(colors.textSecondary)
                    Text(value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(colors.textSecondary)
                        .frame(
                            width: SettingsChromeAccessibility.detailLabelColumnWidth,
                            alignment: .leading
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Text(value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(colors.textPrimary)
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
    @Environment(\.formaColors) private var colors

    var body: some View {
        Divider()
            .overlay(colors.border)
    }
}
