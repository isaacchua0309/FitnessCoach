//
//  WeeklyReviewInsightList.swift
//  Fitness Coach
//
//  Forma — Wins and watch-items for weekly review detail.
//

import SwiftUI

struct WeeklyReviewInsightList: View {
    let title: String
    let items: [WeeklyReviewInsightState]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.contentSpacing) {
                WeeklyReviewSectionHeader(title: title)

                VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.listSpacing) {
                    ForEach(items) { item in
                        insightRow(item)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(listAccessibilityLabel)
            .formaThemeReactive()
        }
    }

    private func insightRow(_ item: WeeklyReviewInsightState) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Circle()
                .fill(indicatorColor(for: item.kind))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
                .accessibilityHidden(true)

            Text(item.message)
                .font(WeeklyReviewTypography.body)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
    }

    private func indicatorColor(for kind: WeeklyReviewInsightKind) -> Color {
        switch kind {
        case .win:
            return FormaTokens.Color.success
        case .risk:
            return FormaTokens.Color.warning
        }
    }

    private var listAccessibilityLabel: String {
        "\(title). \(items.map(\.accessibilityLabel).joined(separator: ". "))"
    }
}

// MARK: - Previews

#Preview("Wins") {
    WeeklyReviewInsightList(
        title: FormaProductCopy.WeeklyReviewPresentation.winsHeader,
        items: WeeklyReviewPresentationPreviewData.strongWeekDetail.wins
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Risks") {
    WeeklyReviewInsightList(
        title: FormaProductCopy.WeeklyReviewPresentation.risksHeader,
        items: WeeklyReviewPresentationPreviewData.strongWeekDetail.risks
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
