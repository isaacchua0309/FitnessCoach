//
//  AuthDiagnosticsView.swift
//  Fitness Coach
//
//  FitPilot — Debug-only auth diagnostics (Settings → Developer).
//

#if DEBUG
import SwiftUI

struct AuthDiagnosticsView: View {

    var body: some View {
        List {
            Section {
                DebugAuthDiagnosticsView()
                    .formaSettingsRowChrome()
            } header: {
                FormaSettingsSectionHeader(title: "Session")
            } footer: {
                Text("Debug only. Token values are never shown. Token check reports Available, Unavailable, or Checking...")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }

            Section {
                AccountDeletionDryRunDiagnosticsView()
                    .formaSettingsRowChrome()
            } header: {
                FormaSettingsSectionHeader(title: "Account deletion backend")
            } footer: {
                Text("Debug only. Sends a non-destructive dry-run probe to the account deletion Cloud Function. No Firestore data is deleted.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .formaGroupedList()
        .navigationTitle("Auth diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
    }
}

#Preview {
    NavigationStack {
        AuthDiagnosticsView()
    }
    .environmentObject(AuthManager())
}
#endif
