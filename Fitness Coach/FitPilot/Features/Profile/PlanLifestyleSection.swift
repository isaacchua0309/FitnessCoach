//
//  PlanLifestyleSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanLifestyleSection: View {
    let lifestyle: PlanLifestyleState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionLabel(title: "Lifestyle")

            VStack(spacing: 0) {
                lifestyleRow("Activity level", lifestyle.activityLevel)
                divider
                lifestyleRow("Training frequency", lifestyle.trainingFrequency)
                divider
                lifestyleRow("Average steps", lifestyle.averageSteps)
                divider
                lifestyleRow("Diet preference", lifestyle.dietPreference)
            }
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 4)
    }

    private func lifestyleRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}
