//
//  TodayDashboardHeader.swift
//  Fitness Coach
//
//  Forma — Today screen header (title + date). Preview/test wrapper around PageHeader.
//

import SwiftUI

struct TodayDashboardHeader: View {
    let date: Date
    var planStatusChip: String?

    var body: some View {
        PageHeader(
            title: FormaProductCopy.Today.Header.title,
            subtitle: TodayDashboardHeaderFormatting.dateLine(for: date),
            trailingAction: {
                if let planStatusChip {
                    PageActionPill(title: planStatusChip)
                }
            }
        )
        .todayLiveTheme()
    }
}

#if DEBUG
#Preview {
    TodayDashboardHeader(
        date: Date(),
        planStatusChip: FormaProductCopy.Today.Header.planStatusNeedsFocus
    )
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
