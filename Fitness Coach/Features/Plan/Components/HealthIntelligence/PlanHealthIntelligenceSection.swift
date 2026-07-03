//
//  PlanHealthIntelligenceSection.swift
//  Fitness Coach
//
//  Forma — Composes Plan Health Intelligence cards into a section stack.
//

import SwiftUI

struct PlanHealthIntelligenceSection: View {
    let state: PlanHealthIntelligenceSectionState
    var onMissingDataAction: ((PlanHealthMissingDataActionState) -> Void)? = nil
    var onConnectHealth: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
            PlanHealthConfidenceCard(
                state: state.confidenceCard,
                isLoading: state.isLoading
            )

            if state.confidenceCard.phase != .empty {
                PlanHealthSignalsCard(
                    sectionTitle: state.dataQuality.sectionTitle,
                    signals: state.dataQuality.signals,
                    isLoading: state.isLoading
                )

                PlanAssumptionsCard(
                    state: state.assumptions,
                    isLoading: state.isLoading
                )

                PlanDataQualityCard(
                    state: state.dataQuality,
                    isLoading: state.isLoading
                )
            }

            if !state.missingDataActions.isEmpty {
                missingDataActionsBlock
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .formaThemeReactive()
    }

    @ViewBuilder
    private var missingDataActionsBlock: some View {
        VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.actionSpacing) {
            ForEach(state.missingDataActions) { action in
                missingDataActionCard(action)
            }
        }
    }

    @ViewBuilder
    private func missingDataActionCard(_ action: PlanHealthMissingDataActionState) -> some View {
        FormaPlanCard {
            VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.rowSpacing) {
                Text(action.title)
                    .font(PlanHealthIntelligenceTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                PlanHealthPhaseMessage(message: action.message)

                if shouldShowActionButton(for: action), let handler = actionHandler(for: action) {
                    Button(action.title, action: handler)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaPlanTokens.Color.planAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                        .buttonStyle(.plain)
                        .padding(.top, PlanHealthIntelligenceCardSupport.rowSpacing)
                        .accessibilityLabel(action.title)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private func shouldShowActionButton(for action: PlanHealthMissingDataActionState) -> Bool {
        action.id == "connect-health" ? onConnectHealth != nil : onMissingDataAction != nil
    }

    private func actionHandler(for action: PlanHealthMissingDataActionState) -> (() -> Void)? {
        if action.id == "connect-health", let onConnectHealth {
            return onConnectHealth
        }
        if let onMissingDataAction {
            return { onMissingDataAction(action) }
        }
        return nil
    }
}

// MARK: - Previews

#Preview("Strong confidence") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.strongFit
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Limited confidence") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.sparseSignals,
            onMissingDataAction: { _ in }
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Disconnected") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.disconnected,
            onConnectHealth: {}
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Partial data") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.partialData,
            onMissingDataAction: { _ in }
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Loading") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.loading
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme — Blossom Pink") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.strongFit
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .blossomPink)
}

#Preview("Dark mode") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.strongFit
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .preferredColorScheme(.dark)
}
