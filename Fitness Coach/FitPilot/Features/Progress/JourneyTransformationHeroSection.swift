//
//  JourneyTransformationHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyTransformationHeroSection: View {
    let state: JourneyTransformationState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.goalTitle)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(state.startedLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 24) {
                weightColumn("Current", state.currentWeightKg)
                weightColumn("Goal", state.goalWeightKg)
            }

            if let progress = state.progressPercent {
                SwiftUI.ProgressView(value: min(progress, 100) / 100)
                    .tint(.primary)
            }

            HStack {
                if let eta = state.estimatedCompletionLabel {
                    meta("Estimated", eta)
                }
                Spacer()
                meta("Phase", state.currentPhase)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Coach")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(state.coachInsight)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weightColumn(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatKg(value))
                .font(.title2.weight(.semibold))
        }
    }

    private func meta(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func formatKg(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))kg"
            : String(format: "%.1fkg", value)
    }
}
