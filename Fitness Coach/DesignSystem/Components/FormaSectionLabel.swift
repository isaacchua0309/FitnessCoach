//
//  FormaSectionLabel.swift
//  Fitness Coach
//
//  Forma — Shared uppercase section label for dashboard screens.
//

import SwiftUI

struct FormaSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
