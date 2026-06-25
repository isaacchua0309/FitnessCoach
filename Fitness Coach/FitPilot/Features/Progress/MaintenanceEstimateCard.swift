//
//  MaintenanceEstimateCard.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic maintenance estimate card.
//

import SwiftUI

struct MaintenanceEstimateCard: View {
    let estimate: MaintenanceEstimate?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Maintenance Estimate", systemImage: "speedometer")
                .font(.headline)

            if let estimate, estimate.hasEnoughData, let maintenance = estimate.estimatedMaintenanceCalories {
                ProgressMetricCard(
                    title: "Estimated maintenance",
                    value: ProgressFormatter.kcal(maintenance),
                    subtitle: ProgressFormatter.confidence(estimate.confidence),
                    systemImage: "flame"
                )

                if let change = estimate.weightChangeKg {
                    ProgressMetricCard(
                        title: "Weight change",
                        value: ProgressFormatter.kgChange(change),
                        subtitle: "\(estimate.days) logged days",
                        systemImage: "arrow.up.and.down"
                    )
                }
            } else {
                Text("You need at least 7 days of food logs and weigh-ins before maintenance estimates become useful.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    MaintenanceEstimateCard(estimate: ProgressPreviewData.state.maintenanceEstimate)
        .padding()
}
