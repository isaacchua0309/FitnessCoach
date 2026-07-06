//
//  JourneyChapterSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyChapterSection: View {
    let state: JourneyChapterState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.sectionTitle)

            JourneyCard(elevation: .quiet) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    chapterHeader

                    JourneyProgressBar(progress: state.progressPercent / 100)
                        .accessibilityLabel(state.chapterTitle)
                        .accessibilityValue("\(Int(state.progressPercent.rounded())) percent")

                    if let nextUnlock = state.nextUnlockLabel {
                        Text(nextUnlock)
                            .font(JourneyTypography.cardSupporting)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityHidden(true)
                    }

                    if let emptyMessage = state.emptyMessage {
                        Text(emptyMessage)
                            .font(FormaTokens.Typography.caption2)
                            .foregroundStyle(FormaTokens.Color.textTertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var chapterHeader: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            Text(FormaProductCopy.Journey.Chapters.chapterLabel(state.chapterNumber))
                .font(JourneyTypography.cardHeadline)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .accessibilityHidden(true)

            Text(state.chapterTitle)
                .font(JourneyTypography.cardSupporting.weight(.medium))
                .foregroundStyle(FormaTokens.Theme.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Journey chapter") {
    ScrollView {
        JourneyChapterSection(state: JourneyPreviewData.strongMomentum.chapter)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
