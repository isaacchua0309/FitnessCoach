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

    private let userProfileService: UserProfileService

    init(userProfileService: UserProfileService) {
        self.userProfileService = userProfileService
    }

    func load() {
        do {
            state = RootProfileRouteResolver.resolve(
                hasProfile: try userProfileService.getCurrentProfile() != nil
            )
        } catch {
            state = .error(FormaProductCopy.Error.loadProfile)
        }
    }

    func didCompleteOnboarding() {
        state = .main
    }

    func retry() {
        load()
    }
}
