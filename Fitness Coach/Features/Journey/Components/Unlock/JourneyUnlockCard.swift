//
//  JourneyUnlockCard.swift
//  Fitness Coach
//
//  Forma — Checklist card for Journey unlock progress.
//

import SwiftUI

struct JourneyUnlockCard: View {
    let checklist: JourneyUnlockChecklistState
    var style: Style = .standard

    enum Style: Equatable {
        case standard
        case compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact
            ? WeeklyProgressCardSupport.blockSpacing
            : FormaTokens.Spacing.sm) {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                Text(checklist.title)
                    .font(style == .compact
                        ? WeeklyProgressCardSupport.blockTitleFont
                        : JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                JourneyProgressDots(
                    completedCount: checklist.completedCount,
                    totalCount: checklist.totalCount
                )
            }

            VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                ForEach(checklist.items) { item in
                    JourneyChecklistRow(item: item)
                }
            }
        }
        .padding(WeeklyProgressCardSupport.blockPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaCardChrome.background(.surfaceSubtle))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(checklist.accessibilityLabel)
        .accessibilityIdentifier("journey-unlock-card")
    }
}

#if DEBUG
#Preview("Unlock checklist") {
    let dashboard = JourneyPreviewData.brandNewUser
    if let checklist = dashboard.screenPresentation.unlockDashboard.checklist {
        JourneyUnlockCard(checklist: checklist)
            .padding()
            .background(FormaTokens.Color.canvas)
            .formaThemePreview()
    }
}
#endif
