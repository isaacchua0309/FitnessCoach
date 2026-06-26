//
//  AccountSettingsView.swift
//  Fitness Coach
//
//  FitPilot — Consumer account screen (Settings → Account).
//

import SwiftUI

struct AccountSettingsView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var showsLogoutConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                profileHeader
                accountDetailsSection
                logoutSection

                Text(FormaProductCopy.Account.dataSeparateNote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, FitPilotScreenStyle.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.sm)
            .padding(.bottom, FormaTokens.Spacing.xs)
        }
        .fitPilotDarkScreenBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .fitPilotScrollBottomInset()
        .confirmationDialog(
            FormaProductCopy.Account.logoutConfirmationTitle,
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                authManager.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(logoutConfirmationMessage)
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            avatarView

            VStack(spacing: 4) {
                if let displayName = accountDisplayName {
                    Text(displayName)
                        .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .multilineTextAlignment(.center)
                }

                if let email = accountEmail {
                    Text(email)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                if showsSignedInBadge {
                    Label("Signed in with Google", systemImage: "checkmark.circle.fill")
                        .font(FormaTokens.Typography.caption.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(FormaTokens.Color.surfaceElevated)
                .frame(width: 72, height: 72)
                .overlay(
                    Circle()
                        .stroke(FormaTokens.Color.border, lineWidth: 1)
                )

            if showsStatusProgress {
                SwiftUI.ProgressView()
                    .tint(FormaTokens.Color.textPrimary)
            } else {
                Text(profileInitials)
                    .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
            }
        }
        .accessibilityLabel(avatarAccessibilityLabel)
    }

    // MARK: - Account details

    private var accountDetailsSection: some View {
        FitPilotPlanCard {
            VStack(spacing: 0) {
                FitPilotPlanDisplayRow(label: "Name", value: accountDisplayName ?? "—")
                FitPilotPlanRowDivider()
                FitPilotPlanDisplayRow(
                    label: "Email",
                    value: accountEmail ?? "—",
                    multilineValue: true
                )
                FitPilotPlanRowDivider()
                FitPilotPlanDisplayRow(label: "Sign-in method", value: "Google")
            }
        }
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
                .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                .fill(FormaTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
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

    private var logoutConfirmationMessage: String {
        FormaProductCopy.Account.logoutConfirmationMessage
    }
}

// MARK: - Previews

#Preview("Signed in") {
    NavigationStack {
        AccountSettingsView()
    }
    .environmentObject(AuthManager())
}
