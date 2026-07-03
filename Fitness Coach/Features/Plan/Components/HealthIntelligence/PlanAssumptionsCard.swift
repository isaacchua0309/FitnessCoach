//
//  PlanAssumptionsCard.swift
//  Fitness Coach
//
//  Forma — Health-signal assumptions shaping the current plan.
//

import SwiftUI

struct PlanAssumptionsCard: View {
    let state: PlanHealthAssumptionsState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.headerToCardSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            PlanHealthIntelligenceLoadingContainer(isLoading: isLoading) {
                FormaPlanCard {
                    VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.contentSpacing) {
                        PlanHealthPhaseMessage(message: state.summary)

                        if !state.items.isEmpty {
                            assumptionRows
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("plan-hi-assumptions-card")
        .formaThemeReactive()
    }

    @ViewBuilder
    private var assumptionRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    FormaPlanRowDivider()
                }
                assumptionRow(item)
            }
        }
        .padding(.top, PlanHealthIntelligenceCardSupport.rowSpacing)
    }

    @ViewBuilder
    private func assumptionRow(_ item: PlanAssumptionItemState) -> some View {
        AssumptionRowView(item: item)
    }
}

private struct AssumptionRowView: View {
    let item: PlanAssumptionItemState

    @ScaledMetric(relativeTo: .caption) private var limitedDotSize: CGFloat = 6

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(item.label)
                .font(PlanHealthIntelligenceTypography.rowLabel)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            HStack(spacing: FormaTokens.Spacing.xs) {
                if item.isLimited {
                    Circle()
                        .fill(FormaTokens.Color.warning)
                        .frame(width: limitedDotSize, height: limitedDotSize)
                        .accessibilityHidden(true)
                }

                Text(item.value)
                    .font(PlanHealthIntelligenceTypography.rowValue)
                    .foregroundStyle(
                        item.isLimited
                            ? FormaTokens.Color.textSecondary
                            : FormaTokens.Color.textPrimary
                    )
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
    }
}

// MARK: - Previews

#Preview("Strong assumptions") {
    PlanAssumptionsCard(state: PlanHealthIntelligencePresentationPreviewData.strongFit.assumptions)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Limited assumptions") {
    PlanAssumptionsCard(state: PlanHealthIntelligencePresentationPreviewData.sparseSignals.assumptions)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Disconnected") {
    PlanAssumptionsCard(state: PlanHealthIntelligencePresentationPreviewData.disconnected.assumptions)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Loading") {
    PlanAssumptionsCard(
        state: PlanHealthIntelligencePresentationPreviewData.strongFit.assumptions,
        isLoading: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme — Blossom Pink") {
    PlanAssumptionsCard(state: PlanHealthIntelligencePresentationPreviewData.strongFit.assumptions)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(palette: .blossomPink)
}
