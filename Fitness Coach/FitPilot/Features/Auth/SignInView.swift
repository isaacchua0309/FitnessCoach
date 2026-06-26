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
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing) {
                SignInHeroCard()
                SignInBenefitsCard()

                if let failurePresentation {
                    SignInFailureBanner(
                        title: failurePresentation.title,
                        message: failurePresentation.message
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.sm)
            .padding(.bottom, FormaTokens.Spacing.md)
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(SignInScreenBackground())
        .animation(.easeInOut(duration: 0.2), value: failurePresentation != nil)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SignInCTAFooter(
                isLoading: isSigningIn,
                isDisabled: isButtonDisabled,
                onSignIn: signInWithGoogle
            )
        }
        .safeAreaPadding(.top, FormaTokens.Spacing.xs)
        .preferredColorScheme(.dark)
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

    private var failurePresentation: AuthSignInPresentationPolicy.FailurePresentation? {
        AuthSignInPresentationPolicy.failurePresentation(authState: authManager.authState)
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        guard !isButtonDisabled else { return }
        Task {
            await authManager.signInWithGoogle()
        }
    }
}

// MARK: - Copy

private enum SignInCopy {
    static let appName = FormaProductCopy.appName
    static let tagline = FormaProductCopy.tagline
    static let valueProposition = FormaProductCopy.SignIn.valueProposition
    static let continueWithGoogle = FormaProductCopy.SignIn.continueWithGoogle
    static let signingIn = FormaProductCopy.SignIn.signingIn
    static let signingInAccessibility = FormaProductCopy.SignIn.signingInAccessibility
    static let trustNote = FormaProductCopy.SignIn.trustNote
    static let legalIntro = FormaProductCopy.SignIn.legalIntro
    static let termsLinkTitle = FormaProductCopy.SignIn.termsLinkTitle
    static let privacyPolicyLinkTitle = FormaProductCopy.SignIn.privacyPolicyLinkTitle
}

// MARK: - Screen chrome

private struct SignInScreenBackground: View {
    var body: some View {
        ZStack {
            FormaTokens.Color.canvas

            RadialGradient(
                colors: [
                    FormaTokens.Color.accent.opacity(0.14),
                    FormaTokens.Color.accent.opacity(0.03),
                    .clear
                ],
                center: .top,
                startRadius: 4,
                endRadius: 360
            )

            LinearGradient(
                colors: [
                    FormaTokens.Color.accent.opacity(0.04),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.38)
            )
        }
        .ignoresSafeArea()
    }
}

private struct SignInSurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(FormaTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .fill(FormaTokens.Color.surfaceElevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        FormaTokens.Color.accent.opacity(0.24),
                                        FormaTokens.Color.border
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

// MARK: - Feedback

private struct SignInFailureBanner: View {
    let title: String
    let message: String

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
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(FormaTokens.Color.warning)
        .padding(FormaTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.warning.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(FormaTokens.Color.warning.opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Hero

private struct SignInHeroCard: View {
    var body: some View {
        SignInSurfaceCard {
            VStack(spacing: FormaTokens.Spacing.md) {
                FormaBrandMark(size: .medium)
                    .frame(maxWidth: .infinity)

                VStack(spacing: FormaTokens.Spacing.xs) {
                    Text(SignInCopy.appName)
                        .font(FormaTokens.Typography.screenTitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.85)
                        .lineLimit(1)

                    Text(SignInCopy.tagline)
                        .font(FormaTokens.Typography.bodyMedium)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(SignInCopy.appName). \(SignInCopy.tagline)")
                .accessibilityAddTraits(.isHeader)

                Text(SignInCopy.valueProposition)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(SignInCopy.valueProposition)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Benefits

private struct SignInBenefitsCard: View {
    private let benefits: [(icon: String, title: String)] = FormaProductCopy.SignIn.benefits

    var body: some View {
        SignInSurfaceCard {
            VStack(spacing: 0) {
                ForEach(Array(benefits.enumerated()), id: \.element.title) { index, benefit in
                    SignInBenefitRow(icon: benefit.icon, title: benefit.title)

                    if index < benefits.count - 1 {
                        Divider()
                            .overlay(FormaTokens.Color.border)
                            .padding(.leading, 36)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SignInBenefitRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: FormaTokens.Spacing.xs, style: .continuous)
                    .fill(FormaTokens.Color.accentMuted)
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, FormaTokens.Spacing.xs + 2)
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - CTA footer

private struct SignInCTAFooter: View {
    let isLoading: Bool
    let isDisabled: Bool
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            GoogleSignInButton(
                isLoading: isLoading,
                isDisabled: isDisabled,
                action: onSignIn
            )

            SignInLegalFooter()
        }
        .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
        .padding(.top, FormaTokens.Spacing.sm)
        .padding(.bottom, FormaTokens.Spacing.xs)
        .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(FormaTokens.Color.canvas.opacity(0.94))
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Divider()
                .overlay(FormaTokens.Color.border)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct GoogleSignInButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

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
            .shadow(color: .black.opacity(isLoading ? 0.08 : 0.16), radius: 8, y: 3)
            .contentShape(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .allowsHitTesting(!isDisabled)
        .accessibilityLabel(isLoading ? SignInCopy.signingInAccessibility : SignInCopy.continueWithGoogle)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isLoading ? [.updatesFrequently] : [])
    }

    @ViewBuilder
    private var leadIcon: some View {
        ZStack {
            GoogleGMark()
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
            Text(SignInCopy.continueWithGoogle)
                .opacity(0)

            Text(isLoading ? SignInCopy.signingIn : SignInCopy.continueWithGoogle)
        }
        .font(FormaTokens.Typography.body.weight(.semibold))
        .foregroundStyle(FormaTokens.Color.googleButtonText)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.85)
        .animation(nil, value: isLoading)
        .accessibilityHidden(true)
    }

    private var accessibilityHint: String {
        if isLoading {
            return "Please wait"
        }
        if isDisabled {
            return "Checking sign-in status"
        }
        return "Sign in with your Google account"
    }
}

private struct SignInLegalFooter: View {
    @Environment(\.openURL) private var openURL
    @State private var presentedDocument: FitPilotLegalDocument?

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.xs + 2) {
            Text(SignInCopy.trustNote)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textLegal)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(SignInCopy.trustNote)

            legalAgreement
        }
        .sheet(item: $presentedDocument) { document in
            SignInLegalDocumentSheet(document: document)
        }
    }

    private var legalAgreement: some View {
        ViewThatFits(in: .horizontal) {
            legalAgreementInline
            legalAgreementStacked
        }
        .font(FormaTokens.Typography.caption)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var legalAgreementInline: some View {
        HStack(spacing: 4) {
            Text(SignInCopy.legalIntro)
                .foregroundStyle(FormaTokens.Color.textLegal)
            legalLinkButton(.terms)
            Text("and")
                .foregroundStyle(FormaTokens.Color.textLegal)
            legalLinkButton(.privacyPolicy)
            Text(".")
                .foregroundStyle(FormaTokens.Color.textLegal)
        }
    }

    private var legalAgreementStacked: some View {
        VStack(spacing: 4) {
            Text(SignInCopy.legalIntro)
                .foregroundStyle(FormaTokens.Color.textLegal)

            HStack(spacing: 4) {
                legalLinkButton(.terms)
                Text("and")
                    .foregroundStyle(FormaTokens.Color.textLegal)
                legalLinkButton(.privacyPolicy)
                Text(".")
                    .foregroundStyle(FormaTokens.Color.textLegal)
            }
        }
    }

    private func legalLinkButton(_ document: FitPilotLegalDocument) -> some View {
        Button {
            openLegalDocument(document)
        } label: {
            Text(document.linkTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .underline()
                .foregroundStyle(FormaTokens.Color.accent)
        }
        .buttonStyle(.plain)
        .frame(minWidth: FormaTokens.Layout.minTouchTarget, minHeight: FormaTokens.Layout.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(document.accessibilityTitle)
        .accessibilityHint(document.url == nil ? "Opens in app" : "Opens in browser")
    }

    private func openLegalDocument(_ document: FitPilotLegalDocument) {
        guard let url = document.url else {
            presentedDocument = document
            return
        }
        openURL(url)
    }
}

private struct SignInLegalDocumentSheet: View {
    let document: FitPilotLegalDocument

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing + 4) {
                    Text("Effective \(FitPilotLegalCopy.effectiveDate)")
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                            Text(section.title)
                                .font(FormaTokens.Typography.sectionTitle)
                                .foregroundStyle(FormaTokens.Color.textPrimary)
                                .accessibilityAddTraits(.isHeader)

                            Text(section.body)
                                .font(FormaTokens.Typography.sectionSubtitle)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.top, FormaTokens.Spacing.xs)
                .padding(.bottom, FormaTokens.Spacing.xl)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.visible)
            .navigationTitle(document.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fitPilotDarkScreenBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

#Preview("Ready") {
    SignInView()
        .environmentObject(AuthManager())
}

#Preview("Google Button — Loading") {
    GoogleSignInButton(isLoading: true, isDisabled: true, action: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Sign-In Failed") {
    SignInFailureBanner(
        title: AuthSignInUserMessage.signInFailureTitle,
        message: AuthSignInUserMessage.signInFailureMessage
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Legal Footer") {
    SignInLegalFooter()
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    SignInView()
        .environmentObject(AuthManager())
        .dynamicTypeSize(.accessibility3)
}

#Preview("iPhone SE") {
    SignInView()
        .environmentObject(AuthManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}
