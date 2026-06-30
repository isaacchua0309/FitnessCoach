//
//  JourneyStoryTimelineSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyStoryTimelineSection: View {
    let state: JourneyStoryTimelineState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.Timeline.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if let emptyStateMessage = state.emptyStateMessage {
                        Text(emptyStateMessage)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !state.displayEvents.isEmpty {
                            FormaPlanRowDivider()
                        }
                    }

                    ForEach(Array(state.displayEvents.enumerated()), id: \.element.id) { index, event in
                        timelineRow(event)
                        if index < state.displayEvents.count - 1 {
                            FormaPlanRowDivider()
                        }
                    }
                }
            }
        }
    }

    private func timelineRow(_ event: JourneyTimelineEvent) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Text(event.icon)
                .font(FormaTokens.Typography.sectionSubtitle)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(JourneyFormatter.timelineDayLabel(event.date))
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)

                Text(event.title)
                    .font(
                        FormaTokens.Typography.sectionSubtitle.weight(
                            event.isMajorEvent ? .semibold : .medium
                        )
                    )
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: event))
    }

    private func accessibilityLabel(for event: JourneyTimelineEvent) -> String {
        let dateLabel = JourneyFormatter.timelineDayLabel(event.date)
        if let subtitle = event.subtitle {
            return "\(dateLabel). \(event.title). \(subtitle)"
        }
        return "\(dateLabel). \(event.title)"
    }
}

// MARK: - Previews

#Preview("New user") {
    JourneyStoryTimelineSection(state: JourneyPreviewData.storyTimelineNewUser)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Active story") {
    JourneyStoryTimelineSection(state: JourneyPreviewData.storyTimelineActive)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
