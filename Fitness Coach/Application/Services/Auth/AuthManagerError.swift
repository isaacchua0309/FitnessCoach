//
//  AuthManagerError.swift
//  Fitness Coach
//
//  FitPilot — Auth manager errors for token retrieval and sign-in flows.
//

import Foundation

enum AuthManagerError: LocalizedError {
    case notSignedIn
    case missingToken

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You're not signed in."
        case .missingToken:
            return "We couldn't verify your session."
        }
    }
}
