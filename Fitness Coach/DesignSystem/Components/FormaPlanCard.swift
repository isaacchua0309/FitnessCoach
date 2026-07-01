//
//  FormaPlanCard.swift
//  Fitness Coach
//
//  Forma — Accent-bordered section card for dashboards and settings.
//

import SwiftUI

struct FormaPlanCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FormaCardChrome.background(.surface))
    }
}

struct FormaPlanDisplayRow: View {
    let label: String
    let value: String
    var multilineValue = false

    var body: some View {
        Group {
            if multilineValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                    Text(value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .frame(width: 88, alignment: .leading)
                    Text(value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .padding(.vertical, 2)
    }
}

struct FormaPlanRowDivider: View {
    var body: some View {
        Divider()
            .overlay(FormaTokens.Color.border)
    }
}
