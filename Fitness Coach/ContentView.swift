//
//  ContentView.swift
//  Fitness Coach
//
//  Created by ByteDance on 25/6/26.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var rootModel: RootModel
    @State private var onboardingModel: OnboardingModel?
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _rootModel = StateObject(wrappedValue: container.makeRootModel())
    }

    var body: some View {
        Group {
            switch rootModel.state {
            case .loading:
                VStack(spacing: 12) {
                    SwiftUI.ProgressView()
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .onboarding:
                Group {
                    if let onboardingModel {
                        OnboardingView(model: onboardingModel)
                    } else {
                        SwiftUI.ProgressView()
                    }
                }
                .onAppear {
                    ensureOnboardingModel()
                }
            case .main:
                MainTabView(container: container)
            case .error(let message):
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        rootModel.retry()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .task {
            rootModel.load()
        }
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
    ContentView(container: try! AppContainer(inMemory: true))
}
