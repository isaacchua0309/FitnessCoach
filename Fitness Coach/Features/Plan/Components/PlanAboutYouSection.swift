//
//  PlanAboutYouSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanAboutYouSection: View {
    let aboutYou: PlanAboutYouState

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: "About you")

            FitPilotPlanCard {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(spacing: 0) {
                        FitPilotPlanDisplayRow(label: "Age", value: aboutYou.age)
                        FitPilotPlanRowDivider()
                        FitPilotPlanDisplayRow(label: "Height", value: aboutYou.height)
                        FitPilotPlanRowDivider()
                        FitPilotPlanDisplayRow(label: "Sex", value: aboutYou.sex)
                        if let bodyFat = aboutYou.bodyFat {
                            FitPilotPlanRowDivider()
                            FitPilotPlanDisplayRow(label: "Body fat", value: bodyFat)
                        }
                        FitPilotPlanRowDivider()
                        FitPilotPlanDisplayRow(label: "Units", value: aboutYou.units)
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Your details")
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                }
                .tint(FormaTokens.Color.accent)
            }
        }
    }
}
