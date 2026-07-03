//
//  FormaSettingsRows.swift
//  Fitness Coach
//
//  Forma — Settings section headers and compact row labels.
//

import SwiftUI

struct FormaSettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .textCase(nil)
    }
}

struct FormaSettingsRowLabel: View {
    let title: String
    var status: String?

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .lineLimit(1)

            Spacer(minLength: FormaTokens.Spacing.xs)

            if let status {
                Text(status)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
    }
}
