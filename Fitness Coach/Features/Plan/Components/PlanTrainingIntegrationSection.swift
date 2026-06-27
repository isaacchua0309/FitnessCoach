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
                        FormaActionRow(
                            title: TrainingIntegrationCopy.planIntegrationMessage(
                                isAppleHealthConnected: integrationState.isConnected
                            ),
                            style: .card(
                                systemImage: "heart.text.square.fill",
                                usesLegalText: true,
                                verticalAlignment: .top
                            )
                        )
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
