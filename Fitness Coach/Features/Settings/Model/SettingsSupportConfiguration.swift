//
//  SettingsSupportConfiguration.swift
//  Fitness Coach
//
//  Forma — Support email configuration for Settings.
//

import Foundation

struct SettingsSupportConfiguration: Equatable, Sendable {
    let supportEmail: String?

    static let production = SettingsSupportConfiguration(
        supportEmail: SettingsSupportShippingPolicy.resolvedSupportEmail()
    )

    static let unconfigured = SettingsSupportConfiguration(supportEmail: nil)

    var isConfigured: Bool {
        guard let supportEmail else { return false }
        let trimmed = supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.contains("@")
    }
}

enum SettingsSupportShippingPolicy {

    // TODO: Confirm `FormaProductCopy.Legal.supportEmail` before App Store release.
    static func resolvedSupportEmail() -> String? {
        let email = FormaProductCopy.Legal.supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, email.contains("@") else { return nil }
        return email
    }
}
