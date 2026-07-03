//
//  WeeklyReviewStatsGrid.swift
//  Fitness Coach
//
//  Forma — Compact stat highlights for weekly review detail.
//

import SwiftUI

struct WeeklyReviewStatsGrid: View {
    let state: WeeklyReviewStatsGridState

    private let columns = [
        GridItem(.flexible(), spacing: FormaTokens.Spacing.sm),
        GridItem(.flexible(), spacing: FormaTokens.Spacing.sm)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.sectionSpacing) {
            WeeklyReviewSectionHeader(title: FormaProductCopy.WeeklyReviewPresentation.statsSectionTitle)

            LazyVGrid(columns: columns, alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                ForEach(state.items) { item in
                    WeeklyReviewStatCell(item: item)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .formaThemeReactive()
    }
}

private struct WeeklyReviewStatCell: View {
    let item: WeeklyReviewStatItemState

    var body: some View {
        VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.listSpacing) {
            Text(item.title)
                .font(WeeklyReviewTypography.statLabel)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(item.value)
                .font(WeeklyReviewTypography.statValue)
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)

            if let detail = item.detail {
                Text(detail)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(detailColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Theme.softBackground.opacity(item.isLimited ? 0.45 : 0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(FormaTokens.Theme.borderTint.opacity(0.28), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statAccessibilityLabel)
    }

    private var valueColor: Color {
        item.isLimited ? FormaTokens.Color.textSecondary : FormaTokens.Color.textPrimary
    }

    private var detailColor: Color {
        item.isLimited ? FormaTokens.Color.warning : FormaTokens.Color.textTertiary
    }

    private var statAccessibilityLabel: String {
        var parts = ["\(item.title), \(item.value)"]
        if let detail = item.detail {
            parts.append(detail)
        }
        if item.isLimited {
            parts.append(FormaProductCopy.WeeklyReviewPresentation.limitedStatAccessibilitySuffix)
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Previews

#Preview("Stats grid") {
    WeeklyReviewStatsGrid(state: WeeklyReviewPresentationPreviewData.strongWeekDetail.statsGrid)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Theme matrix") {
    WeeklyReviewStatsGrid(state: WeeklyReviewPresentationPreviewData.strongWeekDetail.statsGrid)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(palette: .emeraldGreen)
}
