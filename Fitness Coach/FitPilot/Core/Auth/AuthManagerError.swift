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
            return "No signed-in Firebase user."
        case .missingToken:
            return "Could not retrieve a Firebase ID token."
        }
    }
}
