//
//  ExistingUserSignInView.swift
//  Fitness Coach
//
//  Forma — Dedicated sign-in for returning users (not onboarding save-plan sign-in).
//

import SwiftUI

struct ExistingUserSignInView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.formaResolvedTheme) private var resolvedTheme

    let analyticsLogger: any PublicEntryAnalyticsLogging
    var analyticsProperties: PublicEntryAnalyticsProperties = PublicEntryAnalyticsProperties()
    let localError: ExistingUserSignInFailureKind?
    let onBack: () -> Void
    let onCreateMyPlan: () -> Void
    let onSignInRequested: () -> Void

    @State private var didLogView = false

    private let copy = FormaProductCopy.PublicEntry.ExistingUserSignIn.self

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FormaTokens.Spacing.md) {
                backButton

                PublicEntryBrandMark(style: .appIcon, palette: palette)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, FormaTokens.Spacing.xs)
                    .accessibilityHidden(true)

                PublicEntryTitleBlock(
                    title: copy.title,
                    subtitle: copy.subtitle,
                    supportingCopy: copy.supportingCopy,
                    palette: palette
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(copy.title). \(copy.subtitle) \(copy.supportingCopy)")

                if let failurePresentation = activeFailurePresentation {
                    PublicEntryFailureBanner(
                        title: failurePresentation.title,
                        message: failurePresentation.message,
                        palette: palette
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                FormaGoogleSignInButton(
                    title: ProfileSignInCopyPolicy.googleButtonTitle(for: .existingUserRestore),
                    isLoading: googleSignInState.isButtonLoading,
                    isDisabled: isGoogleSignInButtonDisabled,
                    action: signInWithGoogle,
                    accessibilityHint: ProfileSignInCopyPolicy.googleButtonAccessibilityHint(
                        for: .existingUserRestore
                    )
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
        .disabled(googleSignInState.isButtonLoading)
        .accessibilityLabel(copy.backAccessibilityLabel)
    }

    private var secondaryCreatePlan: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            Text(copy.newToFormaPrompt)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)

            PublicEntrySecondaryLink(
                title: copy.createMyPlanCTA,
                palette: palette,
                action: onCreateMyPlan,
                font: FormaTokens.Typography.body.weight(.semibold),
                accessibilityHint: copy.createMyPlanAccessibilityHint
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FormaTokens.Spacing.sm)
    }

    // MARK: - State

    private var googleSignInState: GoogleSignInAttemptState {
        authManager.googleSignInAttemptState
    }

    private var isCheckingSession: Bool {
        authManager.authState == .unknown
    }

    private var isGoogleSignInButtonDisabled: Bool {
        googleSignInState.isButtonDisabled || isCheckingSession
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
        guard !isGoogleSignInButtonDisabled else { return }
        onSignInRequested()
    }

    private func logViewedIfNeeded() {
        guard !didLogView else { return }
        didLogView = true
        analyticsLogger.log(.existingSignInViewed, properties: analyticsProperties)
    }
}

// MARK: - Resolving

struct ExistingUserSignInResolvingView: View {

    @Environment(\.formaResolvedTheme) private var resolvedTheme

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    var body: some View {
        PublicEntryLoadingView(
            message: FormaProductCopy.PublicEntry.Loading.restoringPlan,
            palette: palette
        )
    }
}
