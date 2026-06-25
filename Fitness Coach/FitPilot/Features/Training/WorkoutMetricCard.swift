//
//  WorkoutMetricCard.swift
//  Fitness Coach
//
//  FitPilot AI — Small metric tile used by Training.
//

import SwiftUI

struct WorkoutMetricCard: View {
    let title: String
    let value: String
    let caption: String?
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.blue)
                Spacer()
            }
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    WorkoutMetricCard(
        title: "Today",
        value: "2",
        caption: "workouts",
        systemImage: "dumbbell"
    )
    .padding()
}
