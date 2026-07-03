//
//  JourneyHeaderSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyHeaderSection: View {
    let state: JourneyHeaderState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .textCase(.uppercase)
                .accessibilityHidden(true)

            Text(state.subtitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
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
