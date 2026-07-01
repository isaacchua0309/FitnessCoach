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
            .environment(\.publicEntrySessionStore, coordinator.container.publicEntrySessionStore)
            .task {
                coordinator.authManager.startListening()
            }
            .onChange(of: coordinator.effectiveRoute, initial: true) { _, route in
                coordinator.handleEffectiveRouteChange(route)
            }
            .onChange(of: coordinator.authManager.authState, initial: true) { previous, state in
                coordinator.handleAuthStateChange(from: previous, to: state)
            }
            .onChange(of: coordinator.rootModel.state) { _, state in
                coordinator.handleRootStateChange(state)
            }
            .onChange(of: coordinator.container.cloudUploadFailureNotifier.pendingContext) { _, context in
                guard let context else { return }
                coordinator.presentCloudProfileUploadFailure(context: context)
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
