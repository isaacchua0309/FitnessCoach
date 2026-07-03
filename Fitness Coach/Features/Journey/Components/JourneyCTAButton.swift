//
//  JourneyCTAButton.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyCTAButton: View {
    let cta: JourneyCTA
    var title: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: FormaTokens.Spacing.xs) {
                Text(title ?? cta.title)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Theme.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Theme.primary.opacity(0.75))
            }
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(cta.accessibilityHint ?? "")
    }
}
