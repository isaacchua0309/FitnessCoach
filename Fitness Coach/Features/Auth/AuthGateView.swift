//
//  AuthGateView.swift
//  Fitness Coach
//
//  FitPilot — Auth-gated shell with pre-auth onboarding.
//

import SwiftUI

struct AuthGateView: View {

    @StateObject private var coordinator: AuthGateCoordinator

    init(container: AppContainer) {
        _coordinator = StateObject(wrappedValue: AuthGateCoordinator(container: container))
    }

    var body: some View {
        AuthGateRouteView(coordinator: coordinator)
            .environmentObject(coordinator.authManager)
            .environment(\.publicEntrySessionStore, coordinator.publicEntrySessionStore)
            .environment(\.performAppSignOut, coordinator.signOutFromAccount)
            .environment(\.accountDeletionCoordinator, coordinator.accountDeletionCoordinator)
            .environment(\.settingsPrivacyDataEnvironment, coordinator.settingsPrivacyDataEnvironment)
            .task {
                coordinator.activateShell()
            }
            .alert(
                FormaProductCopy.Onboarding.V2.AccountProfileMismatch.useDeviceProfileConfirmTitle,
                isPresented: $coordinator.showUseDeviceProfileConfirmation
            ) {
                Button(
                    FormaProductCopy.Onboarding.V2.AccountProfileMismatch.useDeviceProfileConfirmAction,
                    action: coordinator.confirmUseDeviceProfileAfterPrompt
                )
                Button(
                    FormaProductCopy.Onboarding.V2.AccountProfileMismatch.cancelAction,
                    role: .cancel
                ) {}
            } message: {
                Text(FormaProductCopy.Onboarding.V2.AccountProfileMismatch.useDeviceProfileConfirmBody)
            }
            .alert(
                FormaProductCopy.Onboarding.V2.ProfileConflict.useDevicePlanConfirmTitle,
                isPresented: $coordinator.showUseDevicePlanOverwriteConfirmation
            ) {
                Button(
                    FormaProductCopy.Onboarding.V2.ProfileConflict.useDevicePlanConfirmAction,
                    action: coordinator.confirmUseDevicePlanAfterConflict
                )
                Button(
                    FormaProductCopy.Onboarding.V2.ProfileConflict.cancelAction,
                    role: .cancel
                ) {}
            } message: {
                Text(FormaProductCopy.Onboarding.V2.ProfileConflict.useDevicePlanConfirmBody)
            }
    }
}

#Preview {
    AuthGateView(container: try! AppContainer(inMemory: true))
        .formaThemePreview()
}
