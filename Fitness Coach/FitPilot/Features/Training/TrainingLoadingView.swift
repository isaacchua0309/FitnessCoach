//
//  TrainingLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading state for Training.
//

import SwiftUI

struct TrainingLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            SwiftUI.ProgressView()
            Text("Loading workouts...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TrainingLoadingView()
}
