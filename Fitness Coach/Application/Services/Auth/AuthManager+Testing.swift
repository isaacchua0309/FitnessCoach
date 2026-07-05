//
//  AuthManager+Testing.swift
//  Fitness Coach
//
//  DEBUG-only test seams for auth-gate characterization tests.
//

#if DEBUG
import Foundation

extension AuthManager {

    /// Overrides `authState` for unit/characterization tests without Firebase.
    func applyTestingAuthState(_ state: AuthState) {
        authState = state
    }
}
#endif
