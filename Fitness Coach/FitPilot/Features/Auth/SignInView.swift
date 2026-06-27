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
            VStack(spacing: FormaTokens.Spacing.md) {
                SignInBrandHero()

                SignInValueProp()

                SignInBenefitCluster()

                if let failurePresentation {
                    SignInFailureBanner(
                        title: failurePresentation.title,
                        message: failurePresentation.message
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                GoogleSignInButton(
                    isLoading: isSigningIn,
                    isDisabled: isButtonDisabled,
                    action: signInWithGoogle
                )
                .padding(.top, FormaTokens.Spacing.xs)

                SignInLegalFooter()
                    .padding(.top, FormaTokens.Spacing.xs)
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.xl)
            .padding(.bottom, FormaTokens.Spacing.lg)
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(SignInScreenBackground())
        .animation(.easeInOut(duration: 0.2), value: failurePresentation != nil)
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
}

// MARK: - Screen chrome

private struct SignInScreenBackground: View {
    var body: some View {
        ZStack {
            FormaTokens.Color.canvas

            RadialGradient(
                colors: [
                    FormaTokens.Color.accent.opacity(0.10),
                    FormaTokens.Color.accent.opacity(0.02),
                    .clear
                ],
                center: .top,
                startRadius: 4,
                endRadius: 380
            )

            LinearGradient(
                colors: [
                    FormaTokens.Color.accent.opacity(0.03),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.42)
            )
        }
        .ignoresSafeArea()
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

// MARK: - Brand hero

private struct SignInBrandOrb: View {
    @ScaledMetric(relativeTo: .largeTitle) private var orbDiameter: CGFloat = 68

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FormaTokens.Color.accent.opacity(0.34),
                            FormaTokens.Color.accent.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbDiameter * 0.72
                    )
                )
                .frame(width: orbDiameter * 1.28, height: orbDiameter * 1.28)
                .blur(radius: 10)

            Image("FormaAppIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: orbDiameter, height: orbDiameter)
                .clipShape(Circle())
                .shadow(color: FormaTokens.Color.accent.opacity(0.28), radius: 14, y: 2)
        }
        .accessibilityHidden(true)
    }
}

private struct SignInBrandHero: View {
    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            SignInBrandOrb()
                .frame(maxWidth: .infinity)
                .padding(.bottom, FormaTokens.Spacing.xs)

            VStack(spacing: 6) {
                Text(SignInCopy.appName)
                    .font(FormaTokens.Typography.screenTitle)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)

                Text(SignInCopy.tagline)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(SignInCopy.appName). \(SignInCopy.tagline)")
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Value proposition

private struct SignInValueProp: View {
    var body: some View {
        Text(SignInCopy.valueProposition)
            .font(FormaTokens.Typography.sectionSubtitle)
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(SignInCopy.valueProposition)
    }
}

// MARK: - Benefits

private struct SignInBenefitCluster: View {
    private let benefits: [(icon: String, title: String)] = FormaProductCopy.SignIn.benefits

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            ForEach(benefits, id: \.title) { benefit in
                SignInBenefitRow(icon: benefit.icon, title: benefit.title)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.sm + 2)
        .frame(maxWidth: 340, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .stroke(FormaTokens.Color.border.opacity(0.55), lineWidth: 1)
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
                Circle()
                    .fill(FormaTokens.Color.accentMuted)
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent.opacity(0.92))
            }
            .accessibilityHidden(true)

            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - Google sign-in

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
            .shadow(color: .black.opacity(isLoading ? 0.08 : 0.14), radius: 6, y: 2)
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

// MARK: - Legal footer

private struct SignInLegalFooter: View {
    @State private var presentedDocument: FitPilotLegalDocument?

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.xs + 2) {
            Text(SignInCopy.trustNote)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(SignInCopy.trustNote)

            Text(legalAgreementText)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .multilineTextAlignment(.center)
                .tint(FormaTokens.Color.textSecondary)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(legalAgreementAccessibilityLabel)
        }
        .environment(\.openURL, OpenURLAction(handler: handleLegalURL))
        .sheet(item: $presentedDocument) { document in
            SignInLegalDocumentSheet(document: document)
        }
    }

    private var legalAgreementText: AttributedString {
        var agreement = AttributedString("By continuing, you agree to Forma's ")
        agreement.foregroundColor = UIColor(FormaTokens.Color.textTertiary)

        var terms = AttributedString("Terms")
        terms.link = legalLinkURL(for: .terms)
        terms.underlineStyle = .single
        terms.foregroundColor = UIColor(FormaTokens.Color.textSecondary)

        var conjunction = AttributedString(" and ")
        conjunction.foregroundColor = UIColor(FormaTokens.Color.textTertiary)

        var privacy = AttributedString("Privacy Policy")
        privacy.link = legalLinkURL(for: .privacyPolicy)
        privacy.underlineStyle = .single
        privacy.foregroundColor = UIColor(FormaTokens.Color.textSecondary)

        var suffix = AttributedString(".")
        suffix.foregroundColor = UIColor(FormaTokens.Color.textTertiary)

        agreement.append(terms)
        agreement.append(conjunction)
        agreement.append(privacy)
        agreement.append(suffix)
        return agreement
    }

    private var legalAgreementAccessibilityLabel: String {
        "By continuing, you agree to Forma's Terms and Privacy Policy."
    }

    private func legalLinkURL(for document: FitPilotLegalDocument) -> URL {
        document.url ?? URL(string: "forma-legal://\(document.rawValue)")!
    }

    private func handleLegalURL(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "forma-legal",
              let document = FitPilotLegalDocument(rawValue: url.host ?? "") else {
            return .systemAction
        }

        presentedDocument = document
        return .handled
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
