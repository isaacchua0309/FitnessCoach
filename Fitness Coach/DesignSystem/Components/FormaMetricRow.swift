//
//  FormaMetricRow.swift
//  Fitness Coach
//
//  Forma — Label / value rows for in-card metrics (Journey, Training Insights).
//

import SwiftUI

struct FormaMetricRow: View {
    enum Style {
        /// Label medium primary, value regular secondary (Journey weekly snapshot).
        case snapshot
        /// Label regular primary, value medium secondary (Training Insights).
        case trailingDetail
    }

    let label: String
    let value: String
    var style: Style = .trailingDetail

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(label)
                .font(labelFont)
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Text(value)
                .font(valueFont)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, verticalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    private var labelFont: Font {
        switch style {
        case .snapshot:
            return FormaTokens.Typography.sectionSubtitle.weight(.medium)
        case .trailingDetail:
            return FormaTokens.Typography.sectionSubtitle
        }
    }

    private var valueFont: Font {
        switch style {
        case .snapshot:
            return FormaTokens.Typography.sectionSubtitle
        case .trailingDetail:
            return FormaTokens.Typography.sectionSubtitle.weight(.medium)
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .snapshot:
            return FormaTokens.Spacing.xs
        case .trailingDetail:
            return FormaTokens.Spacing.xs + 2
        }
    }
}

#Preview("Snapshot") {
  FormaMetricRow(label: "Protein", value: "2 of 5 days", style: .snapshot)
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Trailing detail") {
  FormaMetricRow(label: "Workout days", value: "3 days", style: .trailingDetail)
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
