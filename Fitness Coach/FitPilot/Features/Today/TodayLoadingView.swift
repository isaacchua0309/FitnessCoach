//
//  TodayLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading state for Today.
//

import SwiftUI

struct TodayLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading today's dashboard...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TodayLoadingView()
}
