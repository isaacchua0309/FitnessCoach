//
//  HealthPermissionDisplayModel.swift
//  Fitness Coach
//
//  Forma — View-model-friendly Apple Health permission rows (not wired to UI yet).
//

import Foundation

/// User-facing permission connection state for a category row.
enum HealthPermissionDisplayStatus: String, Equatable, Sendable, CaseIterable {
    case connected
    case unavailable
    case denied
    case notDetermined
    case unknown

    init(access: HealthSignalAccess, isHealthDataAvailable: Bool) {
        guard isHealthDataAvailable else {
            self = .unavailable
            return
        }

        switch access {
        case .available:
            self = .connected
        case .unavailable:
            self = .unavailable
        case .denied:
            self = .denied
        case .notDetermined:
            self = .notDetermined
        case .unknown:
            self = .unknown
        }
    }
}

/// A single permission category prepared for display in settings or onboarding.
struct HealthPermissionDisplayModel: Equatable, Sendable, Identifiable {
    let category: HealthPermissionCategory
    let title: String
    let explanation: String
    let whyFormaUsesIt: String
    let requirement: HealthPermissionRequirement
    let status: HealthPermissionDisplayStatus
    let statusLabel: String
    let statusDetail: String
    let requirementLabel: String
    let requirementDetail: String

    var id: HealthPermissionCategory { category }

    var isConnected: Bool { status == .connected }

    var signalKind: HealthSignalKind { category.signalKind }
}

enum HealthPermissionDisplayModelBuilder {

    /// Builds one display row from category metadata and resolved signal access.
    static func make(
        category: HealthPermissionCategory,
        access: HealthSignalAccess,
        isHealthDataAvailable: Bool
    ) -> HealthPermissionDisplayModel {
        let definition = HealthPrivacyCopy.definition(for: category)
        let status = HealthPermissionDisplayStatus(
            access: access,
            isHealthDataAvailable: isHealthDataAvailable
        )

        return HealthPermissionDisplayModel(
            category: category,
            title: definition.title,
            explanation: definition.explanation,
            whyFormaUsesIt: definition.whyFormaUsesIt,
            requirement: definition.requirement,
            status: status,
            statusLabel: HealthPrivacyCopy.Status.label(
                for: status,
                categoryTitle: definition.title
            ),
            statusDetail: HealthPrivacyCopy.Status.detail(
                for: status,
                categoryTitle: definition.title
            ),
            requirementLabel: definition.requirement.title,
            requirementDetail: definition.requirement.detail
        )
    }

    /// Builds display rows for all standard categories from a permission snapshot.
    static func makeAll(from status: HealthPermissionStatus) -> [HealthPermissionDisplayModel] {
        HealthPermissionCategory.displayCategories.map { category in
            make(
                category: category,
                access: status.access(for: category.signalKind),
                isHealthDataAvailable: status.isHealthDataAvailable
            )
        }
    }

    /// Convenience when only a single signal access value is known.
    static func make(
        category: HealthPermissionCategory,
        from status: HealthPermissionStatus
    ) -> HealthPermissionDisplayModel {
        make(
            category: category,
            access: status.access(for: category.signalKind),
            isHealthDataAvailable: status.isHealthDataAvailable
        )
    }
}

extension HealthPermissionDisplayModel {

    /// Privacy overview bullets for grouped presentation surfaces.
    static var privacyOverviewBullets: [String] {
        HealthPrivacyCopy.Principles.overviewBullets
    }

    static var privacyOverviewAccessibilityLabel: String {
        HealthPrivacyCopy.Principles.overviewAccessibilityLabel
    }
}
