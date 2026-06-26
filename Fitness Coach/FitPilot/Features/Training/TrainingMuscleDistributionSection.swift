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

            FitPilotPlanCard {
                if items.isEmpty {
                    Text(FormaProductCopy.Training.muscleEmptyHint)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.name)
                                        .font(FormaTokens.Typography.sectionSubtitle)
                                        .foregroundStyle(FormaTokens.Color.textPrimary)
                                    Spacer()
                                    Text("\(item.setCount) sets")
                                        .font(FormaTokens.Typography.caption)
                                        .foregroundStyle(FormaTokens.Color.textTertiary)
                                }

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(FormaTokens.Color.surfaceSubtle)
                                        Capsule()
                                            .fill(FormaTokens.Color.accent.opacity(0.65))
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
}

#Preview {
    TrainingMuscleDistributionSection(items: TrainingPreviewData.muscleDistribution)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
