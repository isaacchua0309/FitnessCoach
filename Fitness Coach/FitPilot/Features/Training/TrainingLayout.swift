//
//  TrainingLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Training intelligence dashboard.
//

import SwiftUI

enum TrainingLayout {
    static let sectionSpacing: CGFloat = 36
    static let itemSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 20
}

struct TrainingSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}
