//
//  ExistingUserSignInView.swift
//  Fitness Coach
//
//  Forma — Dedicated sign-in for returning users (not onboarding save-plan sign-in).
//

import SwiftUI

struct ExistingUserSignInView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    let analyticsLogger: any PublicEntryAnalyticsLogging
    let localError: ExistingUserSignInFailureKind?
    let onBack: () -> Void
    let onCreateMyPlan: () -> Void
    let onSignInRequested: () -> Void

    @State private var didLogView = false

    private let copy = FormaProductCopy.PublicEntry.ExistingUserSignIn.self

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FormaTokens.Spacing.md) {
                backButton
                brandMark
                titleBlock

                if let failurePresentation = activeFailurePresentation {
                    ExistingUserSignInFailureBanner(
                        title: failurePresentation.title,
                        message: failurePresentation.message,
                        palette: palette
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                FormaGoogleSignInButton(
                    isLoading: isSigningIn,
                    isDisabled: isButtonDisabled,
                    action: signInWithGoogle
                )
                .padding(.top, FormaTokens.Spacing.xs)

                secondaryCreatePlan
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, FormaTokens.Spacing.lg)
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(PublicEntryScreenBackground(palette: palette))
        .animation(.easeInOut(duration: 0.2), value: activeFailurePresentation != nil)
        .onAppear(perform: logViewedIfNeeded)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Sections

    private var backButton: some View {
        Button(action: onBack) {
            Label(FormaProductCopy.Common.back, systemImage: "chevron.left")
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(isSigningIn)
        .accessibilityLabel("Back to welcome")
    }

    private var brandMark: some View {
        ExistingUserSignInBrandMark(palette: palette)
            .frame(maxWidth: .infinity)
            .padding(.bottom, FormaTokens.Spacing.xs)
            .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(copy.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.84)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)

            Text(copy.subtitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.88)

            Text(copy.supportingCopy)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.title). \(copy.subtitle) \(copy.supportingCopy)")
    }

    private var secondaryCreatePlan: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            Text(copy.newToFormaPrompt)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)

            Button(action: onCreateMyPlan) {
                Text(copy.createMyPlanCTA)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(palette.accent)
            }
            .buttonStyle(.plain)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
            .accessibilityHint(copy.createMyPlanAccessibilityHint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FormaTokens.Spacing.sm)
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

    private var activeFailurePresentation: ExistingUserSignInPolicy.FailurePresentation? {
        if let localError {
            return ExistingUserSignInPolicy.presentation(for: localError)
        }
        if AuthSignInPresentationPolicy.shouldShowFailureBanner(authState: authManager.authState) {
            return ExistingUserSignInPolicy.presentation(for: .authFailed)
        }
        return nil
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        guard !isButtonDisabled else { return }
        onSignInRequested()
    }

    private func logViewedIfNeeded() {
        guard !didLogView else { return }
        didLogView = true
        analyticsLogger.log(.existingSignInViewed, properties: PublicEntryAnalyticsProperties())
    }
}

// MARK: - Resolving

struct ExistingUserSignInResolvingView: View {

    @Environment(\.colorScheme) private var colorScheme

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            PublicEntryScreenBackground(palette: palette)

            VStack(spacing: FormaTokens.Spacing.sm) {
                SwiftUI.ProgressView()
                    .controlSize(.large)
                    .tint(palette.accent)

                Text(FormaProductCopy.PublicEntry.ExistingUserSignIn.resolvingMessage)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(FormaProductCopy.PublicEntry.ExistingUserSignIn.resolvingMessage)
    }
}

// MARK: - Chrome

private struct ExistingUserSignInBrandMark: View {
    let palette: PublicWelcomeTheme.Palette

    @ScaledMetric(relativeTo: .largeTitle) private var markDiameter: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.accentSoft)
                .frame(width: markDiameter * 1.18, height: markDiameter * 1.18)

            Image("FormaAppIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: markDiameter, height: markDiameter)
                .clipShape(RoundedRectangle(cornerRadius: markDiameter * 0.22, style: .continuous))
                .shadow(color: palette.accent.opacity(0.16), radius: 12, y: 4)
        }
    }
}

private struct ExistingUserSignInFailureBanner: View {
    let title: String
    let message: String
    let palette: PublicWelcomeTheme.Palette

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Label {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(palette.accent)
        .padding(FormaTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(palette.accentSoft)
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .stroke(palette.surfaceBorder, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Sign In") {
    ExistingUserSignInView(
        analyticsLogger: OSLogPublicEntryAnalyticsLogger(),
        localError: nil,
        onBack: {},
        onCreateMyPlan: {},
        onSignInRequested: {}
    )
    .environmentObject(AuthManager())
}

#Preview("Resolving") {
    ExistingUserSignInResolvingView()
}
