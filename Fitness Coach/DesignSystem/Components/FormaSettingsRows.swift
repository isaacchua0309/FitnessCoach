//
//  FormaSettingsRows.swift
//  Fitness Coach
//
//  Forma — Settings section headers.
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
