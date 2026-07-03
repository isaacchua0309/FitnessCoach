//
//  SettingsAnalyticsContextBuilder.swift
//  Fitness Coach
//
//  Forma — Safe Settings analytics context (no PII or health values).
//

import Foundation

enum SettingsAnalyticsBuildType: String, Sendable {
    case production
    case debug
    case internalBuild = "internal"
}

enum SettingsAnalyticsContextBuilder {

    static func buildType() -> String {
        #if DEBUG
        return SettingsAnalyticsBuildType.debug.rawValue
        #else
        if FormaBuildConfiguration.isInternalBuildEnabled {
            return SettingsAnalyticsBuildType.internalBuild.rawValue
        }
        return SettingsAnalyticsBuildType.production.rawValue
        #endif
    }

    static func rowType(for rowID: SettingsRowID) -> String {
        switch rowID {
        case .account: return "account"
        case .units: return "units"
        case .bodyAndStats: return "body_and_stats"
        case .theme: return "theme"
        case .appleHealth: return "apple_health"
        case .privacyPolicy: return "privacy_policy"
        case .exportData: return "export_data"
        case .deleteData: return "delete_data"
        case .sendFeedback: return "send_feedback"
        case .contactSupport: return "contact_support"
        case .reportProblem: return "report_problem"
        case .appVersion: return "app_version"
        case .termsOfService: return "terms_of_service"
        case .authDiagnostics: return "auth_diagnostics"
        case .pipelineTraces: return "pipeline_traces"
        }
    }

    static func rowType(for topic: SettingsSupportMailTopic) -> String {
        switch topic {
        case .feedback: return "send_feedback"
        case .contactSupport: return "contact_support"
        case .reportProblem: return "report_problem"
        }
    }

    static func appleHealthStatus(_ state: TrainingIntegrationState) -> String {
        switch state {
        case .connected:
            return "connected"
        case .notConnected:
            return "not_connected"
        case .denied:
            return "denied"
        case .requestingPermission:
            return "requesting_permission"
        case .unavailable:
            return "unavailable"
        case .failed:
            return "failed"
        }
    }

    static func unitSystem(_ unitSystem: UnitSystem) -> String {
        unitSystem.rawValue
    }

    static func themeName(_ palette: AppThemePalette) -> String {
        palette.persistenceRawValue
    }

    static func baseProperties(
        unitSystem: UnitSystem?,
        themeName: String?,
        appleHealthStatus: String?
    ) -> SettingsAnalyticsProperties {
        SettingsAnalyticsProperties(
            rowType: nil,
            sectionType: nil,
            appleHealthStatus: appleHealthStatus,
            unitSystem: unitSystem.map(Self.unitSystem),
            themeName: themeName,
            buildType: buildType()
        )
    }

    /// Ensures analytics payloads never include identity or health measurements.
    static func isPrivacySafe(_ parameters: [String: String]) -> Bool {
        let blockedTerms = [
            "email", "name", "age", "sex", "weight", "height",
            "calorie", "kcal", "bmi", "heart", "healthkit", "health_value"
        ]
        for (key, value) in parameters {
            let combined = "\(key) \(value)".lowercased()
            if blockedTerms.contains(where: { combined.contains($0) }) {
                return false
            }
        }
        return true
    }
}
