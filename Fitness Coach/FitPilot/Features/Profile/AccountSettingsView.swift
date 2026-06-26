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
            VStack(alignment: .leading, spacing: 16) {
                profileHeader
                accountDetailsSection
                logoutSection

                Text("Deleting app data is separate from signing out.")
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, FitPilotScreenStyle.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .fitPilotDarkScreenBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .fitPilotScrollBottomInset()
        .confirmationDialog(
            "Log out of FitPilot?",
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
        VStack(spacing: 12) {
            avatarView

            VStack(spacing: 4) {
                if let displayName = accountDisplayName {
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                }

                if let email = accountEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                if showsSignedInBadge {
                    Label("Signed in with Google", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(OnboardingTheme.tertiaryText)
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
                .fill(OnboardingTheme.cardElevated)
                .frame(width: 72, height: 72)
                .overlay(
                    Circle()
                        .stroke(OnboardingTheme.border, lineWidth: 1)
                )

            if showsStatusProgress {
                SwiftUI.ProgressView()
                    .tint(OnboardingTheme.primaryText)
            } else {
                Text(profileInitials)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
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
                .font(.body.weight(.medium))
                .foregroundStyle(.red.opacity(canLogOut ? 0.95 : 0.5))
                .frame(maxWidth: .infinity)
                .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                .fill(OnboardingTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                        .stroke(OnboardingTheme.border, lineWidth: 1)
                )
        )
        .disabled(!canLogOut)
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
        "You'll need to sign in again to use FitPilot. Your local data on this device will not be deleted."
    }
}

// MARK: - Previews

#Preview("Signed in") {
    NavigationStack {
        AccountSettingsView()
    }
    .environmentObject(AuthManager())
}
