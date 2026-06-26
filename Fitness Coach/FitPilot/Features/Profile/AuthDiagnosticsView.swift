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
                    .listRowBackground(OnboardingTheme.card)
            } header: {
                FitPilotSettingsSectionHeader(title: "Session")
            } footer: {
                Text("Debug only. Token values are never shown. Token check reports Available, Unavailable, or Checking...")
                    .foregroundStyle(OnboardingTheme.tertiaryText)
            }
        }
        .fitPilotDarkGroupedList()
        .navigationTitle("Auth diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .fitPilotScrollBottomInset()
    }
}

#Preview {
    NavigationStack {
        AuthDiagnosticsView()
    }
    .environmentObject(AuthManager())
}
#endif
