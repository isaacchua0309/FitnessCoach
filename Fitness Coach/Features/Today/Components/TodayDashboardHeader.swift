//
//  TodayDashboardHeader.swift
//  Fitness Coach
//
//  Forma — Today screen header (title + date).
//

import SwiftUI

struct TodayDashboardHeader: View {
    let date: Date

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            Text(FormaProductCopy.Today.Header.title)
                .font(FormaTokens.Typography.screenTitle)
                .foregroundStyle(theme.primaryText)

            Text(TodayDashboardHeaderFormatting.dateLine(for: date))
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(FormaProductCopy.Today.Header.title). \(TodayDashboardHeaderFormatting.dateLine(for: date))"
        )
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    TodayDashboardHeader(date: Date())
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
