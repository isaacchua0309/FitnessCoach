//
//  MacroProgressRow.swift
//  Fitness Coach
//
//  FitPilot AI — One macro progress row.
//

import SwiftUI

struct MacroProgressRow: View {
    let name: String
    let progress: MacroProgress
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(formatted(progress.consumed)) / \(formatted(progress.target)) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SwiftUI.ProgressView(value: progress.progress)

            Text("\(formatted(progress.remaining)) \(unit) remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview {
    MacroProgressRow(name: "Protein", progress: TodayPreviewData.state.macroSummary.protein, unit: "g")
        .padding()
}
