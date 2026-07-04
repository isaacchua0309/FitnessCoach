//
//  FormaLegalShippingPolicy.swift
//  Fitness Coach
//
//  Forma — Controls which legal documents ship in Settings.
//

import Foundation

enum FormaLegalShippingPolicy {

    /// When `false`, Privacy Policy and Terms rows hide until `FormaLegalURLs` are published.
    /// In-app legal copy exists; flip to `false` to require external URLs in production.
    static var shipsInAppLegalDocumentsWithoutPublishedURL: Bool {
        FormaAbTest.Settings.shipsInAppLegalWithoutPublishedURL
    }

    static func isDocumentAvailableInSettings(
        _ document: FormaLegalDocument,
        externalURL: URL?
    ) -> Bool {
        if externalURL != nil {
            return true
        }
        guard shipsInAppLegalDocumentsWithoutPublishedURL else {
            return false
        }
        return !document.sections.isEmpty
    }
}
