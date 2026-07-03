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
            .padding(.top, SettingsChromeAccessibility.sectionHeaderTopPadding)
            .padding(.bottom, SettingsChromeAccessibility.sectionHeaderBottomPadding)
            .accessibilityAddTraits(.isHeader)
    }
}

struct FormaSettingsRowLabel: View {
    let title: String
    var status: String?
    var showsDisclosure: Bool = false
    var disclosureSystemName: String = "chevron.right"
    var isDestructive: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.leading)
                .lineLimit(SettingsChromeAccessibility.rowTitleLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let status {
                Text(status)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(SettingsChromeAccessibility.statusLineLimit)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            if showsDisclosure {
                Image(systemName: disclosureSystemName)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(
            minHeight: SettingsChromeAccessibility.minimumRowTouchTarget,
            alignment: .center
        )
    }

    private var titleColor: Color {
        isDestructive ? FormaTokens.Color.destructive : FormaTokens.Color.textPrimary
    }
}
