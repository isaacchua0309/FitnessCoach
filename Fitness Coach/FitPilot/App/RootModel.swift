//
//  RootModel.swift
//  Fitness Coach
//
//  FitPilot AI — App root state for onboarding vs main tabs.
//

import Combine
import Foundation

enum RootViewState: Equatable {
    case loading
    case onboarding
    case main
    case error(String)
}

@MainActor
final class RootModel: ObservableObject {

    @Published private(set) var state: RootViewState = .loading

    private let profileBootstrapService: ProfileBootstrapService
    private var loadTask: Task<Void, Never>?

    init(profileBootstrapService: ProfileBootstrapService) {
        self.profileBootstrapService = profileBootstrapService
    }

    func load(uid: String) {
        loadTask?.cancel()
        state = .loading
        loadTask = Task {
            do {
                let result = try await profileBootstrapService.resolve(uid: uid)
                guard !Task.isCancelled else { return }
                state = RootProfileRouteResolver.resolve(bootstrapResult: result)
            } catch {
                guard !Task.isCancelled else { return }
                ProfileBootstrapDebugLogger.error(
                    "Profile bootstrap failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                state = .error(FormaProductCopy.Error.loadProfile)
            }
        }
    }

    func didCompleteOnboarding() {
        state = .main
    }

    func retry(uid: String) {
        load(uid: uid)
    }
}
