//
//  TodayFocusSection.swift
//  Fitness Coach
//
//  Forma — Coach guidance at the top of the Today plan block.
//

import SwiftUI

struct TodayFocusSection: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.focusSectionTitle)

            TodayFocusCard {
                Text(message)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(4)
            }
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
