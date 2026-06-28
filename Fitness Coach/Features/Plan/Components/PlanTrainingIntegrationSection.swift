//
//  PlanTrainingIntegrationSection.swift
//  Fitness Coach
//
//  Forma — Apple Health insights card on the Plan dashboard.
//

import SwiftUI

struct PlanTrainingIntegrationSection: View {
    let integrationState: TrainingIntegrationState
    let dataSource: TrainingDataSource
    let onTap: () -> Void

    private var presentation: PlanTrainingIntegrationPresentation {
        PlanTrainingIntegrationPresentationBuilder.build(integrationState: integrationState)
    }

    var body: some View {
        if dataSource == .appleHealth {
            VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
                FormaSectionLabel(title: presentation.sectionTitle)

                Button(action: onTap) {
                    FitPilotPlanCard {
                        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                            statusRow
                                .accessibilityHidden(true)

                            Text(presentation.bodyCopy)
                                .font(FormaTokens.Typography.sectionSubtitle)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityHidden(true)

                            if let ctaTitle = presentation.ctaTitle {
                                Text(ctaTitle)
                                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                                    .foregroundStyle(FormaTokens.Color.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
                                    .padding(.top, FormaTokens.Spacing.xs)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(presentation.accessibilitySummary)
                .accessibilityHint("Opens Training Insights")
            }
        }
    }

    private var statusRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            if presentation.showsStatusCheckmark {
                Text("✓")
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent)
            }

            Text(presentation.statusLabel)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(
                    presentation.showsStatusCheckmark
                        ? FormaTokens.Color.textPrimary
                        : FormaTokens.Color.textSecondary
                )
        }
    }
}

// MARK: - Previews

#Preview("Connected") {
    PlanTrainingIntegrationSection(
        integrationState: .connected,
        dataSource: .appleHealth,
        onTap: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Not connected") {
    PlanTrainingIntegrationSection(
        integrationState: .notConnected,
        dataSource: .appleHealth,
        onTap: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Denied") {
    PlanTrainingIntegrationSection(
        integrationState: .denied,
        dataSource: .appleHealth,
        onTap: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Unavailable") {
    PlanTrainingIntegrationSection(
        integrationState: .unavailable,
        dataSource: .appleHealth,
        onTap: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
