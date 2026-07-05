//
//  TodayDashboardHeader.swift
//  Fitness Coach
//
//  Forma — Today screen header (title + date).
//

import SwiftUI

struct TodayDashboardHeader: View {
    let date: Date
    var planStatusChip: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(FormaProductCopy.Today.Header.title)
                    .font(FormaTokens.Typography.screenTitle)
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                Spacer(minLength: FormaTokens.Spacing.xs)

                if let planStatusChip {
                    Text(planStatusChip)
                        .font(FormaTokens.Typography.caption2.weight(.semibold))
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .padding(.horizontal, FormaTokens.Spacing.sm)
                        .padding(.vertical, FormaTokens.Spacing.xs)
                        .background(FormaTokens.Theme.softBackground)
                        .clipShape(Capsule())
                        .accessibilityLabel("Plan status: \(planStatusChip)")
                }
            }

            Text(TodayDashboardHeaderFormatting.dateLine(for: date))
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isHeader)
    }

    private var accessibilityLabel: String {
        var parts = [
            FormaProductCopy.Today.Header.title,
            TodayDashboardHeaderFormatting.dateLine(for: date)
        ]
        if let planStatusChip {
            parts.append("Plan status: \(planStatusChip)")
        }
        return parts.joined(separator: ". ")
    }
}

#Preview {
    TodayDashboardHeader(
        date: Date(),
        planStatusChip: FormaProductCopy.Today.Header.planStatusNeedsFocus
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
