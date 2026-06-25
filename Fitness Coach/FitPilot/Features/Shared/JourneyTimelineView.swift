//
//  JourneyTimelineView.swift
//  Fitness Coach
//
//  FitPilot AI — Horizontal weight journey (non-linear progress).
//

import SwiftUI

struct JourneyTimelineView: View {
    let currentLabel: String
    let goalLabel: String
    let remainingLabel: String?
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(currentLabel)
                    .font(.title.weight(.bold))
                Spacer()
                Text(goalLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * progress, 8), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                if let remainingLabel {
                    Text(remainingLabel)
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
            }
        }
    }
}

#Preview {
    JourneyTimelineView(
        currentLabel: "90 kg",
        goalLabel: "75 kg",
        remainingLabel: "15 kg remaining",
        progress: 0.15
    )
    .padding()
}
