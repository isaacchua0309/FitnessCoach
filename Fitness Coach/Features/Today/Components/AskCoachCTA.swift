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
                FormaActionRow(
                    title: FormaProductCopy.Today.askCoachCTATitle,
                    subtitle: FormaProductCopy.Today.askCoachCTASubtitle,
                    style: .card(systemImage: "bubble.left.and.bubble.right")
                )
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
