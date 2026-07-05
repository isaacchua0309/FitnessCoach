//
//  PlanMetricPill.swift
//  Fitness Coach
//
//  Forma — Accent capsule label for Edit Plan metrics and units.
//

import SwiftUI

struct PlanMetricPill: View {
    enum Style {
        case standard
        case compact
    }

    let text: String
    var style: Style = .standard

    var body: some View {
        Text(text)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaPlanTokens.Color.planAccent)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                Capsule()
                    .fill(FormaPlanTokens.Color.planAccentSoft)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .standard:
            return FormaTokens.Spacing.xs
        case .compact:
            return FormaTokens.Spacing.xs
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .standard:
            return 6
        case .compact:
            return 4
        }
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 12) {
        PlanMetricPill(text: "kg")
        PlanMetricPill(text: FormaProductCopy.PlanEditGoal.recommendedBadge, style: .compact)
    }
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
