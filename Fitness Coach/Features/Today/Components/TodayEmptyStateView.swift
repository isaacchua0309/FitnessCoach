//
//  TodayEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Full-screen state when no profile exists on device.
//

import SwiftUI

struct TodayEmptyStateView: View {
    let onOpenPlan: () -> Void

    private var copy: TodayEmptyStateCopy {
        TodayEmptyStateFormatting.copy(for: .missingProfile)
    }

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 44))
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(copy.title)
                .font(FormaTokens.Typography.sectionTitle.weight(.bold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(copy.body)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let actionTitle = copy.actionTitle {
                Button(actionTitle, action: onOpenPlan)
                    .buttonStyle(.borderedProminent)
                    .tint(FormaTokens.Color.accent)
                    .accessibilityHint(copy.accessibilityHint ?? "")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(FormaTokens.Color.canvas)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    TodayEmptyStateView(onOpenPlan: {})
        .preferredColorScheme(.dark)
}
