//
//  CoachTypingIndicatorView.swift
//  Fitness Coach
//
//  FitPilot AI — Subtle typing indicator for Coach.
//

import SwiftUI

struct CoachTypingIndicatorView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.45) % 3
            HStack(spacing: CoachDesignTokens.Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(CoachDesignTokens.Color.tertiaryText)
                        .frame(width: 6, height: 6)
                        .opacity(phase == index ? 1 : 0.35)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, CoachDesignTokens.Spacing.xs)
            .animation(CoachDesignTokens.Motion.quick, value: phase)
        }
    }
}

#Preview {
    CoachTypingIndicatorView()
        .padding()
        .background(CoachDesignTokens.Color.background)
        .preferredColorScheme(.dark)
}
