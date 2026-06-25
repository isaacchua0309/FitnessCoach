//
//  PlanStrategyHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanStrategyHeroSection: View {
    let state: PlanStrategyState
    let onEditPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    PlanSectionLabel(title: "Current strategy")
                    Text(state.strategyName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                }
                Spacer(minLength: 12)
                Button("Edit", action: onEditPlan)
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(state.calorieTargetText)
                    .font(.title3.weight(.semibold))
                Text(state.proteinTargetText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(state.trainingFrequencyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(state.startedLabel)
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Coach")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(state.coachSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
