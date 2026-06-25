//
//  PlanAdaptiveCoachSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanAdaptiveCoachSection: View {
    let state: PlanAdaptiveCoachState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionLabel(title: "Adaptive coach")

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(state.currentStatus)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Future")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    ForEach(state.futureTriggers, id: \.self) { trigger in
                        Text("• \(trigger)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
