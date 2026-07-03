//
//  SettingsSupportDiagnostics.swift
//  Fitness Coach
//
//  Forma — Privacy-safe diagnostic context for support mail.
//

import Foundation

struct SettingsSupportDiagnostics: Equatable, Sendable {
    let appVersion: String
    let buildNumber: String?
    let deviceModel: String
    let systemVersion: String
}

struct SettingsSupportDiagnosticsInput: Equatable, Sendable {
    let appVersion: String
    let buildNumber: String?
    let deviceModel: String
    let systemVersion: String
}

enum SettingsSupportDiagnosticsBuilder {

    static func build(
        bundle: Bundle = .main,
        deviceModel: String = SettingsSupportDeviceInfo.deviceModel,
        systemVersion: String = SettingsSupportDeviceInfo.systemVersion
    ) -> SettingsSupportDiagnostics {
        SettingsSupportDiagnostics(
            appVersion: FormaAppMetadata.marketingVersion(bundle: bundle),
            buildNumber: FormaAppMetadata.buildNumber(bundle: bundle),
            deviceModel: deviceModel,
            systemVersion: systemVersion
        )
    }

    static func build(input: SettingsSupportDiagnosticsInput) -> SettingsSupportDiagnostics {
        SettingsSupportDiagnostics(
            appVersion: input.appVersion,
            buildNumber: input.buildNumber,
            deviceModel: input.deviceModel,
            systemVersion: input.systemVersion
        )
    }
}

enum SettingsSupportMailContent {

    static func subject(for topic: SettingsSupportMailTopic) -> String {
        switch topic {
        case .feedback:
            return FormaProductCopy.Settings.Support.feedbackMailSubject
        case .contactSupport:
            return FormaProductCopy.Settings.Support.contactMailSubject
        case .reportProblem:
            return FormaProductCopy.Settings.Support.reportProblemMailSubject
        }
    }

    static func userPrompt(for topic: SettingsSupportMailTopic) -> String {
        switch topic {
        case .feedback:
            return FormaProductCopy.Settings.Support.feedbackMailPrompt
        case .contactSupport:
            return FormaProductCopy.Settings.Support.contactMailPrompt
        case .reportProblem:
            return FormaProductCopy.Settings.Support.reportProblemMailPrompt
        }
    }

    static func diagnosticFooter(_ diagnostics: SettingsSupportDiagnostics) -> String {
        var lines = [
            FormaProductCopy.Settings.Support.diagnosticsHeader,
            "App version: \(diagnostics.appVersion)"
        ]
        if let buildNumber = diagnostics.buildNumber {
            lines.append("Build: \(buildNumber)")
        }
        lines.append("Device: \(diagnostics.deviceModel)")
        lines.append("iOS: \(diagnostics.systemVersion)")
        return lines.joined(separator: "\n")
    }

    static func messageBody(
        for topic: SettingsSupportMailTopic,
        diagnostics: SettingsSupportDiagnostics
    ) -> String {
        [
            userPrompt(for: topic),
            "",
            diagnosticFooter(diagnostics)
        ].joined(separator: "\n")
    }

    /// Ensures support diagnostics never include health-related fields.
    static func isPrivacySafe(_ body: String) -> Bool {
        let lowered = body.lowercased()
        let blockedTerms = [
            "weight", "kg", "lb", "calorie", "kcal", "bmi", "height", "cm",
            "heart rate", "workout", "healthkit", "apple health", "body fat",
            "protein", "macro", "water", "steps"
        ]
        return !blockedTerms.contains(where: { lowered.contains($0) })
    }
}
