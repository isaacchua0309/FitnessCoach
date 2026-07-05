//
//  JourneyHeaderSection.swift
//  Fitness Coach
//
//  Forma — Journey screen header. Preview/test wrapper around PageHeader.
//

import SwiftUI

struct JourneyHeaderSection: View {
    let state: JourneyHeaderState

    var body: some View {
        PageHeader(
            title: FormaProductCopy.Journey.Header.title,
            subtitle: FormaProductCopy.Journey.Header.subtitle
        )
        .accessibilityLabel(state.accessibilitySummary)
    }
}

#if DEBUG
#Preview {
    JourneyHeaderSection(
        state: JourneyHeaderState(
            title: FormaProductCopy.Journey.Header.title,
            subtitle: FormaProductCopy.Journey.Header.subtitle,
            accessibilitySummary: "\(FormaProductCopy.Journey.Header.title). \(FormaProductCopy.Journey.Header.subtitle)"
        )
    )
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
