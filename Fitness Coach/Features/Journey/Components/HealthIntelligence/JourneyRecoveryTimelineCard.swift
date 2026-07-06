//
//  JourneyRecoveryTimelineCard.swift
//  Fitness Coach
//
//  Forma — Compact 7-day recovery row for Journey Health Intelligence.
//

import SwiftUI

struct JourneyRecoveryTimelineCard: View {
    let state: JourneyRecoveryTimelineState
    var isLoading: Bool = false
    var referenceDay: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.sectionTitle)

            JourneyHealthIntelligenceLoadingCard(isLoading: isLoading || state.phase == .loading) {
                JourneyCard(elevation: .quiet) {
                    VStack(alignment: .leading, spacing: JourneyHealthIntelligenceCardSupport.cardContentSpacing) {
                        cardHeadline

                        switch state.phase {
                        case .loading:
                            loadingContent
                        case .empty:
                            emptyContent
                        case .error:
                            errorContent
                        case .loaded:
                            loadedContent
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("journey-hi-recovery-timeline-card")
        .formaThemeReactive()
    }

    @ViewBuilder
    private var cardHeadline: some View {
        Text(state.headline)
            .font(JourneyTypography.cardSupporting.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .textCase(.uppercase)
            .tracking(0.4)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .accessibilityHidden(state.phase == .loading)
    }

    @ViewBuilder
    private var loadingContent: some View {
        JourneyRecoveryWeekRow(
            days: placeholderDays,
            referenceDay: referenceDay
        )
    }

    @ViewBuilder
    private var emptyContent: some View {
        if !state.days.isEmpty {
            JourneyRecoveryWeekRow(days: state.days, referenceDay: referenceDay)
        }

        if let emptyMessage = state.emptyMessage {
            JourneyHealthIntelligencePhaseMessage(message: emptyMessage)
        }

        if let limitedTimelineNote = state.limitedTimelineNote {
            JourneyHealthIntelligencePhaseMessage(message: limitedTimelineNote, tone: .caution)
        }
    }

    @ViewBuilder
    private var errorContent: some View {
        if let errorMessage = state.errorMessage {
            JourneyHealthIntelligencePhaseMessage(message: errorMessage, tone: .caution)
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if !state.days.isEmpty {
            JourneyRecoveryWeekRow(days: state.days, referenceDay: referenceDay)
        }

        if let limitedTimelineNote = state.limitedTimelineNote {
            JourneyHealthIntelligencePhaseMessage(message: limitedTimelineNote, tone: .caution)
        }

        if let today = state.days.last,
           let explanation = today.shortExplanation,
           !explanation.isEmpty {
            JourneyHealthIntelligencePhaseMessage(message: explanation)
        }
    }

    private var placeholderDays: [JourneyRecoveryDayState] {
        (0..<max(state.dayCount, 7)).map { index in
            JourneyRecoveryDayState(
                id: "placeholder-\(index)",
                date: Date(),
                dateLabel: "—",
                weekdayLabel: "—",
                statusLabel: "—",
                statusKind: .unknown,
                statusColorToken: "recoveryUnknown",
                recoveryScore: nil,
                limitedEstimateLabel: nil,
                shortExplanation: nil,
                isLimitedEstimate: false,
                accessibilityLabel: "Loading"
            )
        }
    }
}

// MARK: - Previews

#Preview("Loaded — 7 days") {
    JourneyRecoveryTimelineCard(
        state: JourneyHealthIntelligencePreviewData.strongWeek.recoveryTimeline,
        referenceDay: Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 3)
        )
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Empty") {
    JourneyRecoveryTimelineCard(
        state: JourneyHealthIntelligencePreviewData.unavailable.recoveryTimeline
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Loading") {
    JourneyRecoveryTimelineCard(
        state: JourneyHealthIntelligencePreviewData.loading.recoveryTimeline,
        isLoading: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme — Blossom Pink") {
    JourneyRecoveryTimelineCard(
        state: JourneyHealthIntelligencePreviewData.strongWeek.recoveryTimeline
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .blossomPink)
}
