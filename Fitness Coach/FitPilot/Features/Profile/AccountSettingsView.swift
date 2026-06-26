//
//  AccountSettingsView.swift
//  Fitness Coach
//
//  FitPilot — Google account status and sign-out (Settings).
//

import SwiftUI

struct AccountSettingsView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var showsLogoutConfirmation = false

    var body: some View {
        Form {
            statusSection
            logoutSection

            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack(alignment: .center, spacing: 12) {
                if showsStatusProgress {
                    SwiftUI.ProgressView()
                        .controlSize(.small)
                }
                Text(statusHeadline)
                    .font(.subheadline)
            }

            if let displayName = accountDisplayName {
                LabeledContent("Name", value: displayName)
            }

            if let email = accountEmail {
                LabeledContent("Email", value: email)
            }
        } header: {
            Text("Status")
        } footer: {
            if isSignedInWithGoogle {
                Text("Your Google account is used to sign in to FitPilot on this device.")
            }
        }
    }

    private var logoutSection: some View {
        Section {
            Button("Log Out", role: .destructive) {
                showsLogoutConfirmation = true
            }
            .disabled(!canLogOut)
        } footer: {
            Text("Deleting app data is separate from signing out. Use Privacy settings when data deletion is available.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            DebugAuthDiagnosticsView()
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Debug builds only. Token values are never shown or logged.")
        }
    }
    #endif

    // MARK: - Status

    private var isSignedInWithGoogle: Bool {
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
        isSignedInWithGoogle && !showsStatusProgress
    }

    private var statusHeadline: String {
        switch authManager.authState {
        case .unknown:
            return "Checking your session…"
        case .signedOut:
            return "Not signed in."
        case .signingIn:
            return "Signing in…"
        case .signedIn:
            return "Signed in with Google"
        case .failed:
            return "Sign-in session unavailable."
        }
    }

    private var accountDisplayName: String? {
        authManager.accountDisplayName
    }

    private var accountEmail: String? {
        authManager.accountEmail
    }

    private var logoutConfirmationMessage: String {
        "You'll need to sign in again to use FitPilot. Your local app data on this device will not be deleted."
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        AccountSettingsView()
    }
    .environmentObject(AuthManager())
}
