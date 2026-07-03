//
//  JourneyChapterSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyChapterSection: View {
    let state: JourneyChapterState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    chapterHeader

                    SwiftUI.ProgressView(value: min(max(state.progressPercent / 100, 0), 1))
                        .tint(FormaTokens.Color.progress)
                        .accessibilityLabel(state.chapterTitle)
                        .accessibilityValue("\(Int(state.progressPercent.rounded())) percent")

                    if let nextUnlock = state.nextUnlockLabel {
                        Text(nextUnlock)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityHidden(true)
                    }

                    if let emptyMessage = state.emptyMessage {
                        Text(emptyMessage)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textTertiary)
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
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(FormaProductCopy.Journey.Chapters.chapterLabel(state.chapterNumber))
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .accessibilityHidden(true)

            Text(state.chapterTitle)
                .font(FormaTokens.Typography.sectionSubtitle)
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
        JourneyChapterSection(state: JourneyPreviewData.chapterActive)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
