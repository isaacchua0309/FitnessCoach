//
//  PlanHealthIntelligenceSection.swift
//  Fitness Coach
//
//  Forma — Composes Plan Health Intelligence cards into a section stack.
//

import SwiftUI

struct PlanHealthIntelligenceSection: View {
    let state: PlanHealthIntelligenceSectionState
    var healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    var onMissingDataAction: ((PlanHealthMissingDataActionState) -> Void)? = nil
    var onConnectHealth: (() -> Void)? = nil

    @State private var isHealthDetailsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
            if let staleDataLabel = state.staleDataLabel {
                planInfoBanner(label: staleDataLabel)
            }

            PlanHealthConfidenceCard(
                state: state.confidenceCard,
                isLoading: state.isLoading
            )
            .onAppear {
                guard !state.isLoading, state.confidenceCard.phase == .loaded else { return }
                healthIntelligenceAnalyticsCoordinator?.logPlanHealthConfidenceViewed(
                    confidenceBucket: HealthIntelligenceAnalyticsContextBuilder.confidenceBucket(
                        from: state.confidenceCard.confidenceLabel
                    )
                )
            }

            if let primaryAction = primaryMissingDataAction {
                missingDataActionCard(primaryAction)
            }

            if !state.isLoading {
                healthDetailsDisclosure
            }

            if let fallbackMessage = state.fallbackMessage {
                planInfoBanner(label: fallbackMessage)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("plan-health-intelligence-section")
        .formaThemeReactive()
    }

    /// Prefer a single primary CTA (connect / permissions) over a multi-card action stack.
    private var primaryMissingDataAction: PlanHealthMissingDataActionState? {
        guard !state.missingDataActions.isEmpty else { return nil }
        if let connect = state.missingDataActions.first(where: { $0.id == "connect-health" }) {
            return connect
        }
        if let permissions = state.missingDataActions.first(where: { $0.id == "partial-permissions" }) {
            return permissions
        }
        return state.missingDataActions.first
    }

    private var healthDetailsDisclosure: some View {
        DisclosureGroup(
            isExpanded: $isHealthDetailsExpanded
        ) {
            VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
                PlanHealthSignalsCard(
                    sectionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.coreSignalsSectionTitle,
                    signals: state.coreSignals,
                    missingSignalsSectionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.missingSignalsSectionTitle,
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
            .padding(.top, FormaTokens.Spacing.sm)
        } label: {
            Text(FormaProductCopy.PlanHealthIntelligencePresentation.confidenceReasonsHeading)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .textCase(.uppercase)
        }
        .tint(FormaTokens.Color.textSecondary)
        .accessibilityIdentifier("plan-hi-health-details-disclosure")
    }

    @ViewBuilder
    private func missingDataActionCard(_ action: PlanHealthMissingDataActionState) -> some View {
        FormaPlanCard {
            VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.rowSpacing) {
                Text(action.title)
                    .font(PlanHealthIntelligenceTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)

                PlanHealthPhaseMessage(message: action.message)

                if shouldShowActionButton(for: action), let handler = actionHandler(for: action) {
                    Button(action.title, action: handler)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Theme.primary)
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
        .accessibilityIdentifier("plan-hi-missing-data-\(action.id)")
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

    @ViewBuilder
    private func planInfoBanner(label: String) -> some View {
        FormaPlanCard {
            Text(label)
                .font(PlanHealthIntelligenceTypography.cardBody)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .healthIntelligenceMultilineText()
        }
        .accessibilityIdentifier("plan-hi-fallback-banner")
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

#Preview("Stale data") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.staleData,
            onMissingDataAction: { _ in }
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Accessibility — Large Text") {
    ScrollView {
        PlanHealthIntelligenceSection(
            state: PlanHealthIntelligencePresentationPreviewData.strongFit
        )
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}
