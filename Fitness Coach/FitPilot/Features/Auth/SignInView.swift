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
            VStack(alignment: .leading, spacing: 18) {
                SignInHeroCard()

                SignInBenefitsPanel()

                if let failurePresentation {
                    SignInFailureBanner(
                        title: failurePresentation.title,
                        message: failurePresentation.message
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, OnboardingTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: SignInLayout.contentMaxWidth)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(SignInScreenBackground())
        .animation(.easeInOut(duration: 0.2), value: failurePresentation != nil)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SignInBottomBar(
                isLoading: isSigningIn,
                isDisabled: isButtonDisabled,
                onSignIn: signInWithGoogle
            )
        }
        .safeAreaPadding(.top, 4)
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

private enum SignInLayout {
    static let contentMaxWidth: CGFloat = 520
    static let minTouchTarget: CGFloat = 44
}

// MARK: - Copy

private enum SignInCopy {
    static let appName = "FitPilot"
    static let tagline = "Your AI fitness coach."
    static let valueProposition = "Build your plan, log with Coach, and pick up where you left off."
    static let continueWithGoogle = "Continue with Google"
    static let signingIn = "Signing in…"
    static let signingInAccessibility = "Signing in"
    static let trustNote = "Your Google account is used to keep your plan available when you sign in."
    static let legalIntro = "By continuing, you agree to FitPilot's"
    static let termsLinkTitle = "Terms"
    static let privacyPolicyLinkTitle = "Privacy Policy"
}

// MARK: - Screen chrome

private struct SignInScreenBackground: View {
    var body: some View {
        ZStack {
            OnboardingTheme.background

            RadialGradient(
                colors: [
                    OnboardingTheme.accent.opacity(0.16),
                    OnboardingTheme.accent.opacity(0.04),
                    .clear
                ],
                center: .top,
                startRadius: 8,
                endRadius: 380
            )

            LinearGradient(
                colors: [
                    OnboardingTheme.accent.opacity(0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.42)
            )
        }
        .ignoresSafeArea()
    }
}

private struct SignInSurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: OnboardingTheme.cornerRadius, style: .continuous)
                    .fill(OnboardingTheme.cardElevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: OnboardingTheme.cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        OnboardingTheme.accent.opacity(0.28),
                                        OnboardingTheme.border
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
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(OnboardingTheme.warning)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .fill(OnboardingTheme.warning.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .stroke(OnboardingTheme.warning.opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Hero

private struct SignInHeroCard: View {
    @ScaledMetric(relativeTo: .largeTitle) private var orbSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var orbRingSize: CGFloat = 76

    var body: some View {
        SignInSurfaceCard {
            VStack(spacing: 16) {
                brandOrb

                VStack(spacing: 6) {
                    Text(SignInCopy.appName)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(SignInCopy.tagline)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(SignInCopy.appName). \(SignInCopy.tagline)")
                .accessibilityAddTraits(.isHeader)

                Text(SignInCopy.valueProposition)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.legalText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(SignInCopy.valueProposition)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var brandOrb: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            OnboardingTheme.accent.opacity(0.45),
                            OnboardingTheme.accent.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .frame(width: orbRingSize, height: orbRingSize)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OnboardingTheme.accent.opacity(0.22),
                            OnboardingTheme.accent.opacity(0.06)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: orbSize * 0.55
                    )
                )
                .frame(width: orbSize, height: orbSize)

            Image(systemName: "figure.run")
                .font(.title2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Benefits

private struct SignInBenefitsPanel: View {
    private let benefits: [(icon: String, title: String)] = [
        ("target", "Personalized plan and daily targets"),
        ("bubble.left.and.bubble.right.fill", "Natural-language logging with Coach"),
        ("chart.line.uptrend.xyaxis", "Progress across nutrition and training")
    ]

    var body: some View {
        SignInSurfaceCard {
            VStack(spacing: 0) {
                ForEach(Array(benefits.enumerated()), id: \.element.title) { index, benefit in
                    SignInBenefitRow(icon: benefit.icon, title: benefit.title)

                    if index < benefits.count - 1 {
                        Divider()
                            .overlay(OnboardingTheme.border.opacity(0.85))
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
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(OnboardingTheme.accent.opacity(0.12))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - Bottom bar

private struct SignInBottomBar: View {
    let isLoading: Bool
    let isDisabled: Bool
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            GoogleSignInButton(
                isLoading: isLoading,
                isDisabled: isDisabled,
                action: onSignIn
            )

            SignInLegalFooter()
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: SignInLayout.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(OnboardingTheme.background.opacity(0.96))
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Divider()
                .overlay(OnboardingTheme.border.opacity(0.9))
        }
        .accessibilityElement(children: .contain)
    }
}

private struct GoogleSignInButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var buttonMinHeight: CGFloat = 52

    private let labelColor = Color(red: 0.24, green: 0.25, blue: 0.26)
    private let leadIconSize: CGFloat = 20

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leadIcon

                label
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(buttonMinHeight, SignInLayout.minTouchTarget))
            .padding(.horizontal, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.border.opacity(0.35), lineWidth: 1)
            )
            .opacity(isLoading ? 0.92 : 1)
            .shadow(color: .black.opacity(isLoading ? 0.08 : 0.18), radius: 10, y: 4)
            .contentShape(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
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
                .tint(labelColor)
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
        .font(.body.weight(.semibold))
        .foregroundStyle(labelColor)
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
        VStack(spacing: 10) {
            Text(SignInCopy.trustNote)
                .font(.caption)
                .foregroundStyle(OnboardingTheme.legalText)
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
        .font(.caption)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var legalAgreementInline: some View {
        HStack(spacing: 4) {
            Text(SignInCopy.legalIntro)
                .foregroundStyle(OnboardingTheme.legalText)
            legalLinkButton(.terms)
            Text("and")
                .foregroundStyle(OnboardingTheme.legalText)
            legalLinkButton(.privacyPolicy)
            Text(".")
                .foregroundStyle(OnboardingTheme.legalText)
        }
    }

    private var legalAgreementStacked: some View {
        VStack(spacing: 4) {
            Text(SignInCopy.legalIntro)
                .foregroundStyle(OnboardingTheme.legalText)

            HStack(spacing: 4) {
                legalLinkButton(.terms)
                Text("and")
                    .foregroundStyle(OnboardingTheme.legalText)
                legalLinkButton(.privacyPolicy)
                Text(".")
                    .foregroundStyle(OnboardingTheme.legalText)
            }
        }
    }

    private func legalLinkButton(_ document: FitPilotLegalDocument) -> some View {
        Button {
            openLegalDocument(document)
        } label: {
            Text(document.linkTitle)
                .font(.caption.weight(.semibold))
                .underline()
                .foregroundStyle(OnboardingTheme.accent)
        }
        .buttonStyle(.plain)
        .frame(minWidth: SignInLayout.minTouchTarget, minHeight: SignInLayout.minTouchTarget)
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
                VStack(alignment: .leading, spacing: 22) {
                    Text("Effective \(FitPilotLegalCopy.effectiveDate)")
                        .font(.caption)
                        .foregroundStyle(OnboardingTheme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .accessibilityAddTraits(.isHeader)

                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(OnboardingTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, OnboardingTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: SignInLayout.contentMaxWidth)
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
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Sign-In Failed") {
    SignInFailureBanner(
        title: AuthSignInUserMessage.signInFailureTitle,
        message: AuthSignInUserMessage.signInFailureMessage
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Legal Footer") {
    SignInLegalFooter()
        .padding()
        .background(OnboardingTheme.background)
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