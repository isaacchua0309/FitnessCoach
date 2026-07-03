//
//  AccountSignInProvider.swift
//  Fitness Coach
//
//  Forma — Sign-in provider labels for Account settings.
//

import Foundation

enum AccountSignInProvider: Equatable, Sendable {
    case google
    case unknown
}

enum AccountSignInProviderLabels {

    static func providerBadge(for provider: AccountSignInProvider) -> String {
        switch provider {
        case .google:
            return FormaProductCopy.Account.signedInBadgeGoogle
        case .unknown:
            return FormaProductCopy.Account.signedInBadgeGeneric
        }
    }

    static func signInMethod(for provider: AccountSignInProvider) -> String {
        switch provider {
        case .google:
            return FormaProductCopy.Account.signInMethodGoogle
        case .unknown:
            return FormaProductCopy.Account.signedInBadgeGeneric
        }
    }
}
