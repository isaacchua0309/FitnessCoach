//
//  JourneyCTAButton.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyCTAButton: View {
    let cta: JourneyCTA
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(cta.title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityHint(cta.accessibilityHint ?? "")
    }
}
