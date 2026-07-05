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

    // TD-SETTINGS-001: Confirm production support email before App Store release. See Docs/TechnicalDebt/TechnicalDebtRegister.md
    static func resolvedSupportEmail() -> String? {
        let email = FormaProductCopy.Legal.supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, email.contains("@") else { return nil }
        return email
    }
}
