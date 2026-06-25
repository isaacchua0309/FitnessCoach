//
//  ProfileLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading state for Profile.
//

import SwiftUI

struct ProfileLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            SwiftUI.ProgressView()
            Text("Loading profile...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ProfileLoadingView()
}
