//
//  TodayFocusSection.swift
//  Fitness Coach
//
//  Forma — One-line coach guidance in the Today status zone.
//

import SwiftUI

struct TodayFocusSection: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.focusSectionTitle)

            Text(message)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textLegal)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(FormaProductCopy.Today.focusSectionTitle): \(message)")
    }
}

#Preview {
    TodayFocusSection(message: FormaProductCopy.Today.focusProteinLow)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
