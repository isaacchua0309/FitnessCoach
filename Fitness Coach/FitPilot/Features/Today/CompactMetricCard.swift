//
//  CompactMetricCard.swift
//  Fitness Coach
//
//  FitPilot AI — Small scannable metric card for the Today dashboard.
//

import SwiftUI

struct CompactMetricCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
    }
}

#Preview {
    HStack(spacing: 8) {
        CompactMetricCard(
            icon: "drop.fill",
            iconColor: .cyan,
            title: "Water",
            value: "1,200 / 3,500 ml",
            actionTitle: "Log",
            action: {}
        )
        CompactMetricCard(
            icon: "scalemass",
            iconColor: .purple,
            title: "Weight",
            value: "90.15 kg",
            actionTitle: "Update",
            action: {}
        )
    }
    .padding()
}
