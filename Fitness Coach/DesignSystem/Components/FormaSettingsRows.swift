//
//  FormaSettingsRows.swift
//  Fitness Coach
//
//  Forma — Settings section headers and placeholder rows.
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

struct FormaComingSoonRow: View {
    let title: String

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.textTertiary)
            Spacer(minLength: 8)
            Text("Coming soon")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary.opacity(0.9))
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), coming soon")
        .accessibilityAddTraits(.isStaticText)
    }
}
