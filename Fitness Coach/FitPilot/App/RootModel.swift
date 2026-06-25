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
            state = try userProfileService.getCurrentProfile() == nil ? .onboarding : .main
        } catch {
            state = .error("Could not load your profile.")
        }
    }

    func didCompleteOnboarding() {
        state = .main
    }

    func retry() {
        load()
    }
}
