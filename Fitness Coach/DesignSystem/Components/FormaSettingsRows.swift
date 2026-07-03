//
//  FormaSettingsRows.swift
//  Fitness Coach
//
//  Forma — Settings section headers and row labels.
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
    var subtitle: String?
    var status: String?

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                }
            }

            Spacer(minLength: FormaTokens.Spacing.xs)

            if let status {
                Text(status)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
    }
}
