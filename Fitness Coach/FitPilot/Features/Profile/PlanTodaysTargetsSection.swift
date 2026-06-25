//
//  PlanTodaysTargetsSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanTodaysTargetsSection: View {
    let targets: PlanTodaysTargetsState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionLabel(title: "Today's targets")

            VStack(spacing: 0) {
                targetRow("Calories", targets.calories)
                divider
                targetRow("Protein", targets.protein)
                divider
                targetRow("Water", targets.water)
                divider
                targetRow("Training", targets.trainingFrequency)
            }
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 4)
    }

    private func targetRow(_ label: String, _ value: String) -> some View {
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
