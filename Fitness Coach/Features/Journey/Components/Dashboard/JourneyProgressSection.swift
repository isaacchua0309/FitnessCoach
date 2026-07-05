//
//  JourneyProgressSection.swift
//  Fitness Coach
//
//  Forma — Compact progress rows for the Journey dashboard.
//

import SwiftUI

struct JourneyProgressSection: View {
    let state: JourneyProgressSectionState
    var onConnectHealth: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: state.sectionTitle)

            JourneyCard(elevation: .quiet) {
                VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                    ForEach(Array(state.rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            FormaPlanRowDivider()
                        }
                        JourneyProgressRowView(row: row)
                    }

                    if let connectCTA = state.connectHealthCTA {
                        if !state.rows.isEmpty {
                            FormaPlanRowDivider()
                        }
                        connectHealthRow(connectCTA)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilitySummary)
        .accessibilityIdentifier("journey-progress-section")
        .formaThemeReactive()
    }

    @ViewBuilder
    private func connectHealthRow(_ cta: JourneyHealthConnectCTAState) -> some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            Text(cta.title)
                .font(JourneyTypography.cardSupporting.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(cta.message)
                .font(FormaTokens.Typography.caption2)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let onConnectHealth {
                Button(action: onConnectHealth) {
                    Text(cta.ctaTitle)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Theme.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cta.ctaTitle)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cta.accessibilityLabel)
    }
}

struct JourneyProgressRowView: View {
    let row: JourneyProgressRowState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            statusSymbol
                .font(JourneyTypography.cardSupporting.weight(.semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 14, alignment: .center)
                .accessibilityHidden(true)

            Text(row.title)
                .font(JourneyTypography.cardSupporting)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.value)
                .font(JourneyTypography.cardSupporting.weight(.semibold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private var statusSymbol: Text {
        switch row.status {
        case .ready:
            return Text("✓")
        case .building:
            return Text("◐")
        case .notStarted, .limited:
            return Text("○")
        }
    }

    private var symbolColor: Color {
        switch row.status {
        case .ready:
            return FormaTokens.Theme.primary
        case .building:
            return FormaTokens.Color.textSecondary
        case .notStarted, .limited:
            return FormaTokens.Color.textTertiary
        }
    }

    private var valueColor: Color {
        switch row.status {
        case .ready:
            return FormaTokens.Theme.primary
        case .building:
            return FormaTokens.Color.textSecondary
        case .notStarted, .limited:
            return FormaTokens.Color.textTertiary
        }
    }
}

#if DEBUG
#Preview("Progress rows") {
    let dashboard = JourneyPreviewData.weekOne
    JourneyProgressSection(state: dashboard.progressSection)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
#endif
