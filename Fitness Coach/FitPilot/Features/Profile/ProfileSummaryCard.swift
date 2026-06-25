//
//  ProfileSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Summary card for profile basics.
//

import SwiftUI

struct ProfileSummaryCard: View {
    let summary: ProfileSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile")
                .font(.headline)

            VStack(spacing: 10) {
                summaryRow("Name", summary.nameText)
                summaryRow("Age", summary.ageText)
                summaryRow("Sex", summary.sexText)
                summaryRow("Height", summary.heightText)
                summaryRow("Current weight", summary.currentWeightText)
                summaryRow("Goal weight", summary.goalWeightText)
                if let bodyFatText = summary.bodyFatText {
                    summaryRow("Body fat", bodyFatText)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

#Preview {
    ProfileSummaryCard(summary: ProfilePreviewData.state.profileSummary)
        .padding()
}
