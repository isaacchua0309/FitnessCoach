//
//  CoachEmptyState.swift
//  Fitness Coach
//
//  FitPilot AI — Calm empty conversation state. Commands live in the toolbar.
//

import SwiftUI

struct CoachEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.md) {
            Spacer(minLength: CoachDesignTokens.Spacing.xl)

            Text(FormaProductCopy.Coach.emptyIntro)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
                ForEach(FormaProductCopy.Coach.examplePrompts, id: \.self) { example in
                    HStack(alignment: .top, spacing: CoachDesignTokens.Spacing.xs) {
                        Text("·")
                            .font(CoachDesignTokens.Typography.hintLabel)
                            .foregroundStyle(CoachDesignTokens.Color.accent.opacity(0.85))
                        Text(example)
                            .font(CoachDesignTokens.Typography.hintLabel)
                            .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 2)

            Text(FormaProductCopy.Coach.emptyToolbarHint)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, CoachDesignTokens.Spacing.xs)

            Spacer(minLength: CoachDesignTokens.Spacing.xl)
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CoachEmptyState()
        .background(CoachDesignTokens.Color.background)
        .preferredColorScheme(.dark)
}
