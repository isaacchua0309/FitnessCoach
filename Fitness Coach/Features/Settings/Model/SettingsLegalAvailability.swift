//
//  SettingsLegalAvailability.swift
//  Fitness Coach
//
//  Forma — Resolves which legal documents are available in Settings.
//

import Foundation

struct SettingsLegalAvailability: Equatable, Sendable {
    let termsURL: URL?
    let privacyPolicyURL: URL?

    static let production = SettingsLegalAvailability(
        termsURL: FormaLegalURLs.terms,
        privacyPolicyURL: FormaLegalURLs.privacyPolicy
    )

    var isPrivacyPolicyAvailable: Bool {
        FormaLegalShippingPolicy.isDocumentAvailableInSettings(
            .privacyPolicy,
            externalURL: privacyPolicyURL
        )
    }

    var isTermsAvailable: Bool {
        FormaLegalShippingPolicy.isDocumentAvailableInSettings(
            .terms,
            externalURL: termsURL
        )
    }

    func externalURL(for document: FormaLegalDocument) -> URL? {
        switch document {
        case .terms:
            return termsURL
        case .privacyPolicy:
            return privacyPolicyURL
        }
    }
}
