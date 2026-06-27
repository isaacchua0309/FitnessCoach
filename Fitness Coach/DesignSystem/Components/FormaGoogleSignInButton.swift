//
//  FormaGoogleSignInButton.swift
//  Fitness Coach
//
//  Forma — Shared Google sign-in button (SignIn screen + onboarding save plan).
//

import SwiftUI

struct FormaGoogleSignInButton: View {
    var title: String = FormaProductCopy.SignIn.continueWithGoogle
    var loadingTitle: String = FormaProductCopy.SignIn.signingIn
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    var accessibilityHint: String?

    @ScaledMetric(relativeTo: .body) private var buttonMinHeight: CGFloat = 52

    private let leadIconSize: CGFloat = 20

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaTokens.Spacing.sm) {
                leadIcon
                label
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(buttonMinHeight, FormaTokens.Layout.minTouchTarget))
            .padding(.horizontal, FormaTokens.Spacing.md)
            .background(FormaTokens.Color.googleButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                    .stroke(FormaTokens.Color.googleButtonBorder, lineWidth: 1)
            )
            .opacity(isLoading ? 0.92 : 1)
            .shadow(color: .black.opacity(isLoading ? 0.08 : 0.14), radius: 6, y: 2)
            .contentShape(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .allowsHitTesting(!isDisabled)
        .accessibilityLabel(isLoading ? FormaProductCopy.SignIn.signingInAccessibility : title)
        .accessibilityHint(resolvedAccessibilityHint)
        .accessibilityAddTraits(isLoading ? [.updatesFrequently] : [])
    }

    @ViewBuilder
    private var leadIcon: some View {
        ZStack {
            Image("GoogleLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .opacity(isLoading ? 0 : 1)

            SwiftUI.ProgressView()
                .controlSize(.small)
                .tint(FormaTokens.Color.googleButtonText)
                .opacity(isLoading ? 1 : 0)
        }
        .frame(width: leadIconSize, height: leadIconSize)
        .accessibilityHidden(true)
    }

    private var label: some View {
        ZStack {
            Text(title)
                .opacity(0)

            Text(isLoading ? loadingTitle : title)
        }
        .font(FormaTokens.Typography.body.weight(.semibold))
        .foregroundStyle(FormaTokens.Color.googleButtonText)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.85)
        .animation(nil, value: isLoading)
        .accessibilityHidden(true)
    }

    private var resolvedAccessibilityHint: String {
        if let accessibilityHint {
            return accessibilityHint
        }
        if isLoading {
            return "Please wait"
        }
        if isDisabled {
            return "Checking sign-in status"
        }
        return "Sign in with your Google account"
    }
}

#Preview("Ready") {
    FormaGoogleSignInButton(isLoading: false, isDisabled: false, action: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Loading") {
    FormaGoogleSignInButton(isLoading: true, isDisabled: true, action: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    FormaGoogleSignInButton(isLoading: false, isDisabled: false, action: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
