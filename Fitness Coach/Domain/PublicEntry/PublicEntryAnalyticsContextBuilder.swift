//
//  PublicEntryAnalyticsContextBuilder.swift
//  Fitness Coach
//
//  Forma — Safe public-entry analytics snapshots (no PII).
//

import Foundation

enum PublicEntryAnalyticsAuthProvider {
    static let google = "google"
}

enum PublicEntryAnalyticsProfileResolution: String, Sendable {
    case profileFoundCloud = "profile_found_cloud"
    case profileFoundLocal = "profile_found_local"
    case noProfileFound = "no_profile_found"
    case lookupFailed = "lookup_failed"
    case conflict = "conflict"
}

enum PublicEntryAnalyticsContextBuilder {

    static func baseProperties(hasLocalProfile: Bool) -> PublicEntryAnalyticsProperties {
        PublicEntryAnalyticsProperties(
            authProvider: PublicEntryAnalyticsAuthProvider.google,
            hasLocalProfile: hasLocalProfile
        )
    }

    static func properties(
        hasLocalProfile: Bool,
        entrySource: PublicEntryEntrySource? = nil,
        profileResolutionResult: ExistingUserSignInResolutionResult? = nil,
        reason: String? = nil
    ) -> PublicEntryAnalyticsProperties {
        var properties = baseProperties(hasLocalProfile: hasLocalProfile)
        properties.entrySource = entrySource?.rawValue
        properties.profileResolutionResult = profileResolutionResult.map(analyticsValue(for:))
        properties.reason = reason
        return properties
    }

    static func analyticsValue(for result: ExistingUserSignInResolutionResult) -> String {
        switch result {
        case .profileFound(.cloudRestored):
            return PublicEntryAnalyticsProfileResolution.profileFoundCloud.rawValue
        case .profileFound(.localOwned):
            return PublicEntryAnalyticsProfileResolution.profileFoundLocal.rawValue
        case .noProfileFound:
            return PublicEntryAnalyticsProfileResolution.noProfileFound.rawValue
        case .lookupFailed:
            return PublicEntryAnalyticsProfileResolution.lookupFailed.rawValue
        case .conflict:
            return PublicEntryAnalyticsProfileResolution.conflict.rawValue
        }
    }
}
