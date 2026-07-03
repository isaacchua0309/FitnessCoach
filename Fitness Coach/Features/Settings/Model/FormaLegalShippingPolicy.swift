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
    #if DEBUG
    static var shipsInAppLegalDocumentsWithoutPublishedURL = true
    #else
    static let shipsInAppLegalDocumentsWithoutPublishedURL = true
    #endif

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
