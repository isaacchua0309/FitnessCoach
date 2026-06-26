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

            FitPilotPlanCard {
                VStack(spacing: 0) {
                    FitPilotPlanDisplayRow(label: "Calories", value: targets.calories)
                    FitPilotPlanRowDivider()
                    FitPilotPlanDisplayRow(label: "Protein", value: targets.protein)
                    FitPilotPlanRowDivider()
                    FitPilotPlanDisplayRow(label: "Water", value: targets.water)
                    FitPilotPlanRowDivider()
                    FitPilotPlanDisplayRow(label: "Training", value: targets.trainingFrequency)
                }
            }
        }
    }
}
