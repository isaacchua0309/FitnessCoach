//
//  TodayQuickActionBar.swift
//  Fitness Coach
//
//  FitPilot AI — Compact horizontal quick-log actions for Today.
//

import SwiftUI

struct TodayQuickActionBar: View {
    let onAddFood: () -> Void
    let onAddWater: () -> Void
    let onLogWeight: () -> Void
    let onOpenTraining: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                actionPill("Add Food", systemImage: "fork.knife", action: onAddFood)
                actionPill("+500 ml", systemImage: "drop.fill", action: onAddWater)
                actionPill("Weight", systemImage: "scalemass", action: onLogWeight)
                actionPill("Workout", systemImage: "dumbbell", action: onOpenTraining)
            }
            .padding(.horizontal, 2)
        }
    }

    private func actionPill(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TodayQuickActionBar(
        onAddFood: {},
        onAddWater: {},
        onLogWeight: {},
        onOpenTraining: {}
    )
    .padding()
}
