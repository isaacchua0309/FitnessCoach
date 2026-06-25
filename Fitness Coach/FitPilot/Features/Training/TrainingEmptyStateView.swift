//
//  TrainingEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Empty state for Training.
//

import SwiftUI

struct TrainingEmptyStateView: View {
    let onAddWorkout: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(spacing: 6) {
                Text("No workouts logged yet.")
                    .font(.title3.weight(.semibold))
                Text("Add a basic workout with exercise sets to start tracking training.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Add Workout", action: onAddWorkout)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TrainingEmptyStateView(onAddWorkout: {})
}
