//
//  WeeklyReviewFocusList.swift
//  Fitness Coach
//
//  Forma — Next-week focus guidance for weekly review detail.
//

import SwiftUI

struct WeeklyReviewFocusList: View {
    let items: [WeeklyReviewFocusItemState]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.contentSpacing) {
                WeeklyReviewSectionHeader(title: FormaProductCopy.WeeklyReviewPresentation.focusHeader)

                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        focusRow(item, index: index + 1)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(focusAccessibilityLabel)
            .formaThemeReactive()
        }
    }

    private func focusRow(_ item: WeeklyReviewFocusItemState, index: Int) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Text("\(index).")
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Theme.primary)
                .frame(width: 18, alignment: .trailing)
                .accessibilityHidden(true)

            Text(item.message)
                .font(WeeklyReviewTypography.body)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, JourneyLayout.compactSpacing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
    }

    private var focusAccessibilityLabel: String {
        "\(FormaProductCopy.WeeklyReviewPresentation.focusHeader). \(items.map(\.accessibilityLabel).joined(separator: ". "))"
    }
}

// MARK: - Previews

#Preview("Focus list") {
    WeeklyReviewFocusList(items: WeeklyReviewPresentationPreviewData.strongWeekDetail.nextWeekFocus)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Dark mode") {
    WeeklyReviewFocusList(items: WeeklyReviewPresentationPreviewData.strongWeekDetail.nextWeekFocus)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
        .preferredColorScheme(.dark)
}
