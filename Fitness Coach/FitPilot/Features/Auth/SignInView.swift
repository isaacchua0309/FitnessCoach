//
//  SignInView.swift
//  Fitness Coach
//
//  FitPilot — Google-only sign-in screen (independent from onboarding and tabs).
//

import SwiftUI

struct SignInView: View {

    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroSection
                    valuePropositionSection

                    if showsFailure {
                        failureBanner
                    }

                    googleSignInButton
                }
                .padding(.horizontal, OnboardingTheme.pagePadding)
                .padding(.vertical, 32)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.16))
                    .frame(width: 88, height: 88)

                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(OnboardingTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("FitPilot")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)

                Text("Your AI fitness coach")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
            }
        }
    }

    // MARK: - Value proposition

    private var valuePropositionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign in to save your plan, log with Coach, and pick up where you left off.")
                .font(.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                valueRow("Personal targets and daily tracking", icon: "target")
                valueRow("Natural-language logging with Coach", icon: "bubble.left.and.bubble.right.fill")
                valueRow("Progress across training and nutrition", icon: "chart.line.uptrend.xyaxis")
            }
        }
    }

    // MARK: - Failure

    private var failureBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(OnboardingTheme.warning)
                .accessibilityHidden(true)

            Text(failureMessage)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .fill(OnboardingTheme.warning.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                        .stroke(OnboardingTheme.warning.opacity(0.35), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sign-in error. \(failureMessage)")
    }

    // MARK: - Google button

    private var googleSignInButton: some View {
        Button {
            signInWithGoogle()
        } label: {
            GoogleContinueButtonLabel(isLoading: isSigningIn)
        }
        .buttonStyle(.plain)
        .disabled(isButtonDisabled)
        .accessibilityLabel(isSigningIn ? "Signing in with Google" : "Continue with Google")
        .accessibilityHint(isButtonDisabled && !isSigningIn ? "Checking sign-in status" : "")
    }

    // MARK: - State

    private var isSigningIn: Bool {
        if case .signingIn = authManager.authState {
            return true
        }
        return false
    }

    private var isCheckingSession: Bool {
        authManager.authState == .unknown
    }

    private var isButtonDisabled: Bool {
        isSigningIn || isCheckingSession
    }

    private var showsFailure: Bool {
        AuthSignInPresentationPolicy.shouldShowFailureBanner(authState: authManager.authState)
    }

    private var failureMessage: String {
        AuthSignInPresentationPolicy.failureBannerMessage(
            authState: authManager.authState,
            errorMessage: authManager.errorMessage
        ) ?? AuthSignInUserMessage.signInFailure
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        guard !isButtonDisabled else { return }
        Task {
            await authManager.signInWithGoogle()
        }
    }

    private func valueRow(_ title: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 22)
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Google continue button

private struct GoogleContinueButtonLabel: View {
    let isLoading: Bool

    private let labelColor = Color(red: 0.24, green: 0.25, blue: 0.26)
    private let borderColor = Color(red: 0.82, green: 0.84, blue: 0.86)

    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                SwiftUI.ProgressView()
                    .controlSize(.small)
                    .tint(labelColor)
                    .frame(width: 20, height: 20)
            } else {
                GoogleGMark()
                    .frame(width: 20, height: 20)
            }

            Text("Continue with Google")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 50)
        .padding(.horizontal, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

/// Simplified multicolor Google "G" mark for the sign-in button.
private struct GoogleGMark: View {
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.0, to: 0.25)
                .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: 3.2)
                .rotationEffect(.degrees(-45))

            Circle()
                .trim(from: 0.25, to: 0.5)
                .stroke(Color(red: 0.98, green: 0.74, blue: 0.02), lineWidth: 3.2)
                .rotationEffect(.degrees(-45))

            Circle()
                .trim(from: 0.5, to: 0.7)
                .stroke(Color(red: 0.20, green: 0.66, blue: 0.33), lineWidth: 3.2)
                .rotationEffect(.degrees(-45))

            Circle()
                .trim(from: 0.7, to: 0.88)
                .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: 3.2)
                .rotationEffect(.degrees(-45))

            Rectangle()
                .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                .frame(width: 9, height: 3.2)
                .offset(x: 2.5)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview {
    SignInView()
        .environmentObject(AuthManager())
}
