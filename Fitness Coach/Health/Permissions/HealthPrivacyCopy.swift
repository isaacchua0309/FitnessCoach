//
//  HealthPrivacyCopy.swift
//  Fitness Coach
//
//  Forma — Production Apple Health privacy and permission education copy.
//
//  Strings are static for now (matches FormaProductCopy). Ready for String Catalog
//  localization when the app adopts standard localization.
//

import Foundation

enum HealthPrivacyCopy {

    // MARK: - Global privacy principles

    enum Principles {
        /// Forma uses Apple Health to personalize coaching.
        static let personalizeCoaching =
            "Forma uses Apple Health to personalize coaching."

        /// Forma reads selected health signals only after permission.
        static let readsAfterPermission =
            "Forma reads selected health signals only after you grant permission."

        /// Forma does not sell health data.
        static let noDataSales =
            "Forma does not sell your health data."

        /// User can revoke access anytime in Apple Health.
        static let revokeAnytime =
            "You can change or revoke access anytime in the Health app."

        /// Some insights may be limited if permissions are missing.
        static let limitedWithoutPermissions =
            "Some insights may stay limited until the related signals are connected."

        /// Raw HealthKit samples are not uploaded; only normalized summaries may sync if enabled.
        static let summariesOnlySync =
            "Raw HealthKit samples are not uploaded. If you turn on cloud sync, only normalized summaries may be stored."

        /// Short overview for cards and onboarding.
        static let overviewBullets: [String] = [
            personalizeCoaching,
            readsAfterPermission,
            noDataSales,
            revokeAnytime,
            limitedWithoutPermissions,
            summariesOnlySync
        ]

        static let overviewAccessibilityLabel =
            "Apple Health privacy: Forma personalizes coaching with your permission, does not sell health data, lets you revoke access in the Health app, and may show limited insights when signals are missing. Raw samples are not uploaded."
    }

    // MARK: - Requirement labels

    enum Requirement {
        static let requiredTitle = "Recommended"
        static let optionalTitle = "Optional"

        static let requiredDetail =
            "Helps Forma show core activity and training guidance on Today and in your plan."
        static let optionalDetail =
            "Adds recovery and progress context when you choose to share it."
    }

    // MARK: - Category definitions

    static func definition(for category: HealthPermissionCategory) -> HealthPermissionCategoryDefinition {
        switch category {
        case .steps:
            return HealthPermissionCategoryDefinition(
                category: .steps,
                title: "Steps",
                explanation: "Your daily step count from Apple Health.",
                whyFormaUsesIt: "Helps Forma show activity progress on Today and keep daily guidance relevant.",
                requirement: .required
            )
        case .workouts:
            return HealthPermissionCategoryDefinition(
                category: .workouts,
                title: "Workouts",
                explanation: "Workouts you log with Apple Health or connected apps.",
                whyFormaUsesIt: "Powers training insights, workout cards on Today, and plan confidence.",
                requirement: .required
            )
        case .activeEnergy:
            return HealthPermissionCategoryDefinition(
                category: .activeEnergy,
                title: "Active energy",
                explanation: "Active calories burned during movement and exercise.",
                whyFormaUsesIt: "Helps Forma understand daily activity load alongside your nutrition plan.",
                requirement: .required
            )
        case .exerciseMinutes:
            return HealthPermissionCategoryDefinition(
                category: .exerciseMinutes,
                title: "Exercise minutes",
                explanation: "Exercise minutes recorded in Apple Health.",
                whyFormaUsesIt: "Helps Forma reflect how much structured movement you logged today.",
                requirement: .required
            )
        case .sleep:
            return HealthPermissionCategoryDefinition(
                category: .sleep,
                title: "Sleep",
                explanation: "Sleep duration and timing from Apple Health.",
                whyFormaUsesIt: "Supports recovery guidance and weekly review context when available.",
                requirement: .optional
            )
        case .restingHeartRate:
            return HealthPermissionCategoryDefinition(
                category: .restingHeartRate,
                title: "Resting heart rate",
                explanation: "Your resting heart rate trend from Apple Health.",
                whyFormaUsesIt: "Adds context to recovery summaries when enough data is available.",
                requirement: .optional
            )
        case .hrv:
            return HealthPermissionCategoryDefinition(
                category: .hrv,
                title: "Heart rate variability",
                explanation: "Heart rate variability (HRV) readings from Apple Health.",
                whyFormaUsesIt: "Supports recovery trends when you choose to share this signal.",
                requirement: .optional
            )
        case .weight:
            return HealthPermissionCategoryDefinition(
                category: .weight,
                title: "Weight",
                explanation: "Body weight entries from Apple Health.",
                whyFormaUsesIt: "Helps Forma show weight progress alongside your plan over time.",
                requirement: .optional
            )
        }
    }

    static var allCategoryDefinitions: [HealthPermissionCategoryDefinition] {
        HealthPermissionCategory.displayCategories.map(definition(for:))
    }

    // MARK: - Permission status copy

    enum Status {
        static func label(
            for displayStatus: HealthPermissionDisplayStatus,
            categoryTitle: String
        ) -> String {
            switch displayStatus {
            case .connected:
                return "Connected"
            case .unavailable:
                return "Unavailable"
            case .denied:
                return "Access off"
            case .notDetermined:
                return "Not connected"
            case .unknown:
                return "Status unclear"
            }
        }

        static func detail(
            for displayStatus: HealthPermissionDisplayStatus,
            categoryTitle: String
        ) -> String {
            switch displayStatus {
            case .connected:
                return "Forma can read \(categoryTitle.lowercased()) from Apple Health."
            case .unavailable:
                return "\(categoryTitle) is not available on this device."
            case .denied:
                return "Turn on \(categoryTitle.lowercased()) for Forma in the Health app."
            case .notDetermined:
                return "Connect Apple Health to allow \(categoryTitle.lowercased()) when you are ready."
            case .unknown:
                return "Forma could not confirm access for \(categoryTitle.lowercased()) yet."
            }
        }
    }

    // MARK: - Screen-level copy

    enum Settings {
        static let screenTitle = "Apple Health permissions"
        static let intro =
            "Choose which signals Forma can read. Forma uses Apple Health to personalize coaching and only reads what you allow."
        static let manageInHealthApp = "Manage in Health app"
    }

    enum Onboarding {
        static let privacyCardTitle = "Your data stays yours"
        static let privacyCardBody =
            "Forma uses Apple Health to personalize coaching, reads signals only after permission, does not sell health data, and lets you revoke access anytime in the Health app."
    }
}

/// Static metadata for a permission category (copy + requirement level).
struct HealthPermissionCategoryDefinition: Equatable, Sendable {
    let category: HealthPermissionCategory
    let title: String
    let explanation: String
    let whyFormaUsesIt: String
    let requirement: HealthPermissionRequirement
}

enum HealthPermissionRequirement: String, Equatable, Sendable, CaseIterable {
    case required
    case optional

    var title: String {
        switch self {
        case .required:
            return HealthPrivacyCopy.Requirement.requiredTitle
        case .optional:
            return HealthPrivacyCopy.Requirement.optionalTitle
        }
    }

    var detail: String {
        switch self {
        case .required:
            return HealthPrivacyCopy.Requirement.requiredDetail
        case .optional:
            return HealthPrivacyCopy.Requirement.optionalDetail
        }
    }
}
