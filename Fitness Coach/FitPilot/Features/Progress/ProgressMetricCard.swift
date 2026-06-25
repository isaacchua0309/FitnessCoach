//
//  ProgressMetricCard.swift
//  Fitness Coach
//
//  FitPilot AI — Small reusable metric row for Progress cards.
//

import SwiftUI

struct ProgressMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let systemImage: String

    init(title: String, value: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

#Preview {
    ProgressMetricCard(title: "Latest", value: "88.90 kg", systemImage: "scalemass")
        .padding()
}
