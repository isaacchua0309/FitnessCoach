//
//  AuthGateView.swift
//  Fitness Coach
//
//  FitPilot — Auth-first shell gate before onboarding or main tabs.
//

import SwiftUI

struct AuthGateView: View {

    @ObservedObject private var authManager: AuthManager
    @StateObject private var rootModel: RootModel
    @State private var onboardingModel: OnboardingModel?
    @State private var signedInSessionID = UUID()

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _authManager = ObservedObject(wrappedValue: container.authManager)
        _rootModel = StateObject(wrappedValue: container.makeRootModel())
    }

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                LaunchLoadingView()
            case .signedOut, .signingIn, .failed:
                SignInView()
            case .signedIn:
                signedInContent
                    .id(signedInSessionID)
            }
        }
        .environmentObject(authManager)
        .task {
            authManager.startListening()
        }
        .onChange(of: authManager.authState, initial: true) { previous, state in
            let wasSignedIn = AppRouteResolver.isSignedIn(previous)
            let isSignedInNow = AppRouteResolver.isSignedIn(state)

            if isSignedInNow {
                if AppRouteResolver.shouldRotateSignedInSession(
                    wasSignedIn: wasSignedIn,
                    isSignedIn: isSignedInNow
                ) {
                    signedInSessionID = UUID()
                }
                rootModel.load()
            } else if AppRouteResolver.shouldClearOnboardingModel(
                wasSignedIn: wasSignedIn,
                isSignedIn: isSignedInNow
            ) {
                onboardingModel = nil
            }
        }
    }

    // MARK: - Signed-in flow

    @ViewBuilder
    private var signedInContent: some View {
        switch rootModel.state {
        case .loading:
            LaunchLoadingView()
        case .onboarding:
            Group {
                if let onboardingModel {
                    OnboardingView(model: onboardingModel)
                } else {
                    LaunchLoadingView()
                }
            }
            .onAppear {
                ensureOnboardingModel()
            }
        case .main:
            MainTabView(container: container)
        case .error(let message):
            profileErrorView(message: message)
        }
    }

    private func profileErrorView(message: String) -> some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.warning)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    rootModel.retry()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }

    private func ensureOnboardingModel() {
        guard onboardingModel == nil else { return }
        onboardingModel = container.makeOnboardingModel {
            onboardingModel = nil
            rootModel.didCompleteOnboarding()
        }
    }
}

#Preview {
    AuthGateView(container: try! AppContainer(inMemory: true))
}
