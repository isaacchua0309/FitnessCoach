//
//  AuthState.swift
//  Fitness Coach
//
//  FitPilot — Firebase authentication state for the app shell.
//

import Foundation

enum AuthState: Equatable {
    /// Initial state before the auth listener reports the first session snapshot.
    case unknown
    case signedOut
    case signingIn
    case signedIn(uid: String)
    case failed(String)
}
