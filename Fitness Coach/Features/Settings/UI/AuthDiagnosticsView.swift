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
