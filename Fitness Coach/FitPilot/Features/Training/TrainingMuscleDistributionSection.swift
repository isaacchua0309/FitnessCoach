//
//  TrainingMuscleDistributionSection.swift
//  Fitness Coach
//
//  FitPilot AI — Muscle distribution from logged exercises (read-only).
//

import SwiftUI

struct TrainingMuscleDistributionSection: View {
    let items: [MuscleDistributionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            TrainingSectionLabel(title: "Muscle distribution")

            if items.isEmpty {
                Text("Log workouts in Coach to see muscle balance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(item.setCount) sets")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.15))
                                    Capsule()
                                        .fill(Color.primary.opacity(0.55))
                                        .frame(width: geometry.size.width * item.progress)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TrainingMuscleDistributionSection(items: TrainingPreviewData.muscleDistribution)
        .padding()
}
