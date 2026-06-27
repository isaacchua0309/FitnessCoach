//
//  PlanTrainingIntegrationSection.swift
//  Fitness Coach
//
//  Forma — Apple Health training integration on Plan (Stage 10).
//

import SwiftUI

struct PlanTrainingIntegrationSection: View {
    let integrationState: TrainingIntegrationState
    let dataSource: TrainingDataSource
    let onTap: () -> Void

    var body: some View {
        if dataSource == .appleHealth {
            VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
                PlanSectionLabel(title: TrainingIntegrationCopy.planIntegrationSectionTitle)

                Button(action: onTap) {
                    FitPilotPlanCard {
                        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                            Image(systemName: "heart.text.square.fill")
                                .font(FormaTokens.Typography.body)
                                .foregroundStyle(FormaTokens.Color.accent)

                            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                                Text(
                                    TrainingIntegrationCopy.planIntegrationMessage(
                                        isAppleHealthConnected: integrationState.isConnected
                                    )
                                )
                                .font(FormaTokens.Typography.sectionSubtitle)
                                .foregroundStyle(FormaTokens.Color.textLegal)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(FormaTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.textTertiary)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(planAccessibilityLabel)
                .accessibilityHint("Opens Training Insights")
            }
        }
    }

    private var planAccessibilityLabel: String {
        if integrationState.isConnected {
            return TrainingIntegrationCopy.planConnectedNote
        }
        return TrainingIntegrationCopy.planConnectPrompt
    }
}

#Preview("Not connected") {
    PlanTrainingIntegrationSection(
        integrationState: .notConnected,
        dataSource: .appleHealth,
        onTap: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Connected") {
    PlanTrainingIntegrationSection(
        integrationState: .connected,
        dataSource: .appleHealth,
        onTap: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
