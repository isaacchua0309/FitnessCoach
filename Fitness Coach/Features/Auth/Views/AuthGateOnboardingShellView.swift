//
//  AuthGateOnboardingShellView.swift
//  Fitness Coach
//
//  Onboarding shell wrapper for pre-auth and signed-in auth gate routes.
//

import SwiftUI

struct AuthGateOnboardingShellView: View {
    @ObservedObject var coordinator: AuthGateCoordinator
    let onAppear: () -> Void
    let onExitToWelcome: () -> Void

    var body: some View {
        Group {
            if let onboardingModel = coordinator.onboardingModel {
                if AppRouteResolver.isSignedIn(coordinator.authManager.authState) {
                    OnboardingView(model: onboardingModel)
                } else {
                    OnboardingView(model: onboardingModel, onExitToWelcome: onExitToWelcome)
                }
            } else {
                LaunchLoadingView()
            }
        }
        .onAppear(perform: onAppear)
    }
}
