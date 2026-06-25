//
//  ProgressLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading state for Progress.
//

import SwiftUI

struct ProgressLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            SwiftUI.ProgressView()
            Text("Loading progress trends...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ProgressLoadingView()
}
