//
//  PlanAboutYouSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanAboutYouSection: View {
    let aboutYou: PlanAboutYouState

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                aboutRow("Age", aboutYou.age)
                divider
                aboutRow("Height", aboutYou.height)
                divider
                aboutRow("Sex", aboutYou.sex)
                if let bodyFat = aboutYou.bodyFat {
                    divider
                    aboutRow("Body fat", bodyFat)
                }
                divider
                aboutRow("Units", aboutYou.units)
            }
            .padding(.top, 8)
        } label: {
            Text("About you")
                .font(.subheadline.weight(.semibold))
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 4)
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
