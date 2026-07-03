//
//  JourneyStoryTimelineSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyStoryTimelineSection: View {
    let state: JourneyStoryTimelineState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: FormaProductCopy.Journey.Timeline.sectionTitle)

            JourneyCard(elevation: .quiet) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if let emptyStateMessage = state.emptyStateMessage {
                        Text(emptyStateMessage)
                            .font(JourneyTypography.cardSupporting)
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
                .font(.system(size: 16))
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                Text(JourneyFormatter.timelineDayLabel(event.date))
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(FormaTokens.Color.textTertiary)

                Text(event.title)
                    .font(
                        event.isMajorEvent
                            ? JourneyTypography.cardHeadline
                            : JourneyTypography.metricLabel
                    )
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(JourneyTypography.cardSupporting)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .lineLimit(2)
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

#Preview("Active story") {
    JourneyStoryTimelineSection(state: JourneyPreviewData.storyTimelineActive)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
