//
//  FormaGoogleSignInButton.swift
//  Fitness Coach
//
//  Forma — Shared Google sign-in button (SignIn screen + onboarding save plan).
//

import SwiftUI

enum FormaGoogleSignInButtonPhase: Equatable {
    case idle
    case loading
    case success
}

struct FormaGoogleSignInButton: View {
    var title: String = FormaProductCopy.SignIn.continueWithGoogle
    var loadingTitle: String = FormaProductCopy.SignIn.signingIn
    var successTitle: String = FormaProductCopy.Common.continueAction
    var successAccessibilityLabel: String?
    let isLoading: Bool
    var showsSuccess: Bool = false
    let isDisabled: Bool
    let action: () -> Void
    var accessibilityHint: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var buttonMinHeight: CGFloat = 56

    private let leadIconSize: CGFloat = 22
    private let cornerRadius = FormaTokens.Radius.button

    private var phase: FormaGoogleSignInButtonPhase {
        if showsSuccess { return .success }
        if isLoading { return .loading }
        return .idle
    }

    private var isInteractionDisabled: Bool {
        isDisabled || phase == .loading || phase == .success
    }

    var body: some View {
        Button(action: action) {
            buttonChrome
        }
        .buttonStyle(FormaGoogleSignInPressStyle())
        .disabled(isInteractionDisabled)
        .allowsHitTesting(!isInteractionDisabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(resolvedAccessibilityHint)
        .accessibilityAddTraits(accessibilityTraits)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: phase)
    }

    private var buttonChrome: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            leadingSymbol
            phaseLabel
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: max(buttonMinHeight, FormaTokens.Layout.minTouchTarget))
        .padding(.horizontal, FormaTokens.Spacing.md)
        .background(FormaTokens.Color.googleButtonBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(FormaTokens.Color.googleButtonBorder, lineWidth: 1)
        }
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            y: shadowY
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var leadingSymbol: some View {
        ZStack {
            Image("GoogleLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .opacity(phase == .idle ? 1 : 0)
                .scaleEffect(phase == .idle ? 1 : 0.85)

            SwiftUI.ProgressView()
                .controlSize(.small)
                .tint(FormaTokens.Color.googleButtonText)
                .opacity(phase == .loading ? 1 : 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: leadIconSize, weight: .semibold))
                .foregroundStyle(FormaTokens.Color.success)
                .symbolRenderingMode(.hierarchical)
                .opacity(phase == .success ? 1 : 0)
                .scaleEffect(phase == .success ? 1 : 0.85)
        }
        .frame(width: leadIconSize, height: leadIconSize)
        .accessibilityHidden(true)
    }

    private var phaseLabel: some View {
        Text(displayedTitle)
            .font(FormaTokens.Typography.body.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.googleButtonText)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.85)
            .lineLimit(1)
            .accessibilityHidden(true)
    }

    private var displayedTitle: String {
        switch phase {
        case .idle:
            return title
        case .loading:
            return loadingTitle
        case .success:
            return successTitle
        }
    }

    private var shadowColor: Color {
        switch phase {
        case .idle:
            return FormaTokens.Color.googleButtonShadow
        case .loading:
            return FormaTokens.Color.googleButtonShadowLoading
        case .success:
            return FormaTokens.Color.googleButtonShadow.opacity(0.85)
        }
    }

    private var shadowRadius: CGFloat {
        phase == .idle ? 8 : 6
    }

    private var shadowY: CGFloat {
        phase == .idle ? 3 : 2
    }

    private var accessibilityLabel: String {
        switch phase {
        case .idle:
            return title
        case .loading:
            return FormaProductCopy.SignIn.signingInAccessibility
        case .success:
            return successAccessibilityLabel ?? successTitle
        }
    }

    private var accessibilityTraits: AccessibilityTraits {
        phase == .loading ? [.updatesFrequently] : []
    }

    private var resolvedAccessibilityHint: String {
        if let accessibilityHint, phase == .idle {
            return accessibilityHint
        }
        switch phase {
        case .loading:
            return "Please wait"
        case .success:
            return "Sign-in complete"
        case .idle:
            if isDisabled {
                return "Checking sign-in status"
            }
            return accessibilityHint ?? "Sign in with your Google account"
        }
    }
}

// MARK: - Press style

private struct FormaGoogleSignInPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(pressedScale(isPressed: configuration.isPressed))
            .animation(pressAnimation, value: configuration.isPressed)
    }

    private func pressedScale(isPressed: Bool) -> CGFloat {
        guard isPressed, !reduceMotion else { return 1 }
        return 0.98
    }

    private var pressAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }
}

// MARK: - Previews

#Preview("Ready") {
    FormaGoogleSignInButton(isLoading: false, isDisabled: false, action: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Loading") {
    FormaGoogleSignInButton(isLoading: true, isDisabled: true, action: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Success") {
    FormaGoogleSignInButton(
        isLoading: false,
        showsSuccess: true,
        isDisabled: true,
        action: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    FormaGoogleSignInButton(isLoading: false, isDisabled: false, action: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
        .dynamicTypeSize(.accessibility3)
}
