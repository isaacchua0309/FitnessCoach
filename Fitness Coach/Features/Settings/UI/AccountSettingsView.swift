//
//  AccountSettingsView.swift
//  Fitness Coach
//
//  Forma — Consumer account screen (Settings → Account).
//

import SwiftUI

struct AccountSettingsView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.performAppSignOut) private var performAppSignOut
    @State private var showsLogoutConfirmation = false

    @ScaledMetric(relativeTo: .title2) private var avatarDiameter: CGFloat = 64

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                profileHeader
                accountDetailsCard
                logoutSection

                Text(FormaProductCopy.Account.signOutDataNote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, FormaTokens.Spacing.sm)
        }
        .formaScreenBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
        .confirmationDialog(
            FormaProductCopy.Account.logoutConfirmationTitle,
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                if let performAppSignOut {
                    performAppSignOut()
                } else {
                    authManager.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(FormaProductCopy.Account.logoutConfirmationMessage)
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            avatarView

            VStack(spacing: FormaTokens.Spacing.xs) {
                if let displayName = accountDisplayName {
                    Text(displayName)
                        .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                if let email = accountEmail {
                    Text(email)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            if showsSignedInBadge {
                signedInBadge
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            FormaTokens.Color.accent.opacity(0.5),
                            FormaTokens.Color.accent.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: avatarDiameter + 6, height: avatarDiameter + 6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FormaTokens.Color.accent.opacity(0.18),
                            FormaTokens.Color.surfaceElevated
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: avatarDiameter * 0.55
                    )
                )
                .frame(width: avatarDiameter, height: avatarDiameter)
                .overlay {
                    Circle()
                        .stroke(FormaTokens.Color.border, lineWidth: 0.5)
                }

            if showsStatusProgress {
                SwiftUI.ProgressView()
                    .tint(FormaTokens.Color.textPrimary)
            } else {
                Text(profileInitials)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
        .accessibilityLabel(avatarAccessibilityLabel)
    }

    private var signedInBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(FormaTokens.Typography.caption)
            Text("Signed in with Google")
                .font(FormaTokens.Typography.caption.weight(.medium))
        }
        .foregroundStyle(FormaTokens.Color.textSecondary)
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(FormaTokens.Color.surface)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(FormaTokens.Color.border, lineWidth: 1)
                }
        )
        .padding(.top, 2)
        .accessibilityLabel("Signed in with Google")
    }

    // MARK: - Details card

    private var accountDetailsCard: some View {
        FormaPlanCard {
            VStack(alignment: .leading, spacing: 0) {
                AccountInfoRow(
                    label: "Name",
                    value: accountDisplayName ?? "—"
                )

                accountRowDivider

                AccountInfoRow(
                    label: "Email",
                    value: accountEmail ?? "—",
                    layout: .stacked,
                    allowsTextSelection: true
                )

                accountRowDivider

                AccountInfoRow(
                    label: "Sign-in",
                    value: "Google"
                )
            }
        }
    }

    private var accountRowDivider: some View {
        Divider()
            .overlay(FormaTokens.Color.border)
            .padding(.vertical, FormaTokens.Spacing.xs)
    }

    // MARK: - Logout

    private var logoutSection: some View {
        Button {
            showsLogoutConfirmation = true
        } label: {
            Text("Log out")
                .font(FormaTokens.Typography.body.weight(.medium))
                .foregroundStyle(FormaTokens.Color.destructive.opacity(canLogOut ? 0.95 : 0.5))
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                .fill(FormaTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                        .stroke(FormaTokens.Color.border, lineWidth: 1)
                )
        )
        .disabled(!canLogOut)
        .accessibilityLabel("Log out")
        .accessibilityHint(canLogOut ? FormaProductCopy.Account.signOutHint : "Unavailable while signing in")
    }

    // MARK: - Helpers

    private var showsSignedInBadge: Bool {
        if case .signedIn = authManager.authState {
            return true
        }
        return false
    }

    private var showsStatusProgress: Bool {
        switch authManager.authState {
        case .unknown, .signingIn:
            return true
        default:
            return false
        }
    }

    private var canLogOut: Bool {
        showsSignedInBadge && !showsStatusProgress
    }

    private var accountDisplayName: String? {
        authManager.accountDisplayName
    }

    private var accountEmail: String? {
        authManager.accountEmail
    }

    private var profileInitials: String {
        if let name = accountDisplayName {
            let parts = name.split(whereSeparator: \.isWhitespace)
            let initials = parts.prefix(2).compactMap(\.first)
            if !initials.isEmpty {
                return String(initials).uppercased()
            }
        }
        if let email = accountEmail, let first = email.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private var avatarAccessibilityLabel: String {
        if let name = accountDisplayName {
            return "Profile photo for \(name)"
        }
        return "Profile photo"
    }
}

// MARK: - Account row

private struct AccountInfoRow: View {

    enum Layout {
        case inline
        case stacked
    }

    let label: String
    let value: String
    var layout: Layout = .inline
    var allowsTextSelection: Bool = false

    private let labelColumnWidth: CGFloat = 76

    var body: some View {
        Group {
            switch layout {
            case .inline:
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
                    labelText
                        .frame(width: labelColumnWidth, alignment: .leading)

                    valueText
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .stacked:
                VStack(alignment: .leading, spacing: 4) {
                    labelText
                    valueText
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FormaTokens.Spacing.xs)
    }

    private var labelText: some View {
        Text(label)
            .font(FormaTokens.Typography.sectionSubtitle)
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }

    @ViewBuilder
    private var valueText: some View {
        let text = Text(value)
            .font(FormaTokens.Typography.sectionSubtitle)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)

        if allowsTextSelection {
            text.textSelection(.enabled)
        } else {
            text
        }
    }
}

// MARK: - Previews

#Preview("Signed in") {
    NavigationStack {
        AccountSettingsView()
    }
    .environmentObject(AuthManager())
}
