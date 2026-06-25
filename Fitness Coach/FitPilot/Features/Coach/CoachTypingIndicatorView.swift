//
//  CoachTypingIndicatorView.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight typing/processing indicator.
//

import SwiftUI

struct CoachTypingIndicatorView: View {
    var body: some View {
        HStack(spacing: 8) {
            SwiftUI.ProgressView()
                .controlSize(.small)
            Text("Coach is thinking...")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

#Preview {
    CoachTypingIndicatorView()
}
