//
//  CoachToolbar.swift
//  Fitness Coach
//
//  FitPilot AI — Persistent, horizontally scrollable Coach command toolbar.
//

import SwiftUI

struct CoachToolbar: View {
    let actions: [CoachToolbarAction]
    let isDisabled: Bool
    let onTap: (CoachToolbarAction) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CoachDesignTokens.Spacing.xs) {
                ForEach(actions) { action in
                    Button {
                        CoachHaptics.toolbarTap()
                        onTap(action)
                    } label: {
                        HStack(spacing: CoachDesignTokens.Spacing.xs) {
                            Image(systemName: action.symbolName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(CoachDesignTokens.Color.accent)

                            Text(action.label)
                                .font(CoachDesignTokens.Typography.chip)
                                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                        }
                        .padding(.horizontal, CoachDesignTokens.Spacing.sm + 2)
                        .frame(minHeight: CoachDesignTokens.Layout.chipMinTouch)
                        .background(CoachDesignTokens.Color.chipFill, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(CoachDesignTokens.Color.chipStroke, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(CoachToolbarButtonStyle())
                    .disabled(isDisabled)
                    .accessibilityLabel(action.label)
                    .accessibilityHint(action.accessibilityHint)
                }
            }
            .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
            .padding(.vertical, CoachDesignTokens.Spacing.xs)
        }
        .background(CoachDesignTokens.Color.background.opacity(0.98))
    }
}

private struct CoachToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(CoachDesignTokens.Motion.quick, value: configuration.isPressed)
    }
}

#Preview {
    VStack {
        Spacer()
        CoachToolbar(
            actions: [.meal, .water, .photo, .weight, .workout, .protein],
            isDisabled: false,
            onTap: { _ in }
        )
    }
    .background(CoachDesignTokens.Color.background)
    .preferredColorScheme(.dark)
}
