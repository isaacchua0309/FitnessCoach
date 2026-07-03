//
//  JourneyHeaderSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyHeaderSection: View {
    let state: JourneyHeaderState

    var body: some View {
        JourneyEyebrowLabel(title: state.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilitySummary)
    }
}

#if DEBUG
#Preview {
    JourneyHeaderSection(
        state: JourneyHeaderState(
            title: FormaProductCopy.Journey.Header.title,
            subtitle: FormaProductCopy.Journey.Momentum.buildingHeadline,
            accessibilitySummary: "Your journey"
        )
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
