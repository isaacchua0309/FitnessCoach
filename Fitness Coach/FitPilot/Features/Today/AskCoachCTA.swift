//
//  AskCoachCTA.swift
//  Fitness Coach
//
//  FitPilot AI — Routes users to Coach for all logging and updates.
//

import SwiftUI

struct AskCoachCTA: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: FormaTokens.Spacing.xs + 2) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(FormaTokens.Typography.body.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.accent)
                Text(FormaProductCopy.Today.askCoachCTA)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm + 2)
            .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
            .background(
                RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                    .fill(FormaTokens.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                            .stroke(FormaTokens.Color.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FormaProductCopy.Today.askCoachCTA)
        .accessibilityHint("Opens Coach")
    }
}

#Preview {
    AskCoachCTA(onTap: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
