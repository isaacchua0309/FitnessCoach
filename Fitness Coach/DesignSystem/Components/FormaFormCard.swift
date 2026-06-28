//
//  FormaFormCard.swift
//  Fitness Coach
//
//  Forma — Grouped form section card.
//

import SwiftUI

struct FormaFormCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            if let title {
                FormaSectionLabel(title: title)
            }

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    content
                }
            }
        }
    }
}
