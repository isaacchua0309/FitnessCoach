//
//  AskCoachCTA.swift
//  Fitness Coach
//
//  FitPilot AI — Routes users to Coach for all logging and updates.
//

import SwiftUI

struct AskCoachCTA: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            FitPilotPlanCard {
                HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(FormaTokens.Typography.body.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(FormaProductCopy.Today.askCoachCTATitle)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(FormaProductCopy.Today.askCoachCTASubtitle)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                }
                .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .center)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(FormaProductCopy.Today.askCoachCTATitle). \(FormaProductCopy.Today.askCoachCTASubtitle)"
        )
        .accessibilityHint(FormaProductCopy.Today.askCoachCTAAccessibilityHint)
    }
}

#Preview {
    AskCoachCTA(onTap: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
