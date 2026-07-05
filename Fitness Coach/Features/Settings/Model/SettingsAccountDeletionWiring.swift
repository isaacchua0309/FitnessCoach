//
//  SettingsAccountDeletionWiring.swift
//  Fitness Coach
//
//  Forma — Combines deletion capability flags with runtime coordinator wiring.
//

import Foundation

struct SettingsAccountDeletionWiring: Equatable, Sendable {
    let featureAvailability: SettingsFeatureAvailability
    let hasCoordinator: Bool

    init(
        featureAvailability: SettingsFeatureAvailability = .production,
        hasCoordinator: Bool
    ) {
        self.featureAvailability = featureAvailability
        self.hasCoordinator = hasCoordinator
    }

    static func resolved(
        featureAvailability: SettingsFeatureAvailability = .production,
        coordinator: AccountDeletionCoordinator?
    ) -> SettingsAccountDeletionWiring {
        SettingsAccountDeletionWiring(
            featureAvailability: featureAvailability,
            hasCoordinator: coordinator != nil
        )
    }

    var canOpenDeleteAccountFlow: Bool {
        featureAvailability.isDeleteAccountEnabled && hasCoordinator
    }

    var canOpenDeleteLocalDeviceFlow: Bool {
        featureAvailability.isDeleteLocalDeviceDataEnabled && hasCoordinator
    }

    var showsDeleteAccountRow: Bool {
        featureAvailability.isDeleteAccountEnabled
    }

    var showsDeleteLocalDeviceRow: Bool {
        featureAvailability.isDeleteLocalDeviceDataEnabled
    }
}

#if DEBUG
import OSLog

enum SettingsAccountDeletionWiringDiagnostics {

    private static let logger = Logger(subsystem: "Forma", category: "SettingsAccountDeletionWiring")

    static func logMissingCoordinatorIfNeeded(
        coordinator: AccountDeletionCoordinator?,
        accountConnection: SettingsPrivacyDataStatusSnapshot.AccountConnection,
        source: String
    ) {
        guard coordinator == nil else { return }
        guard case .signedIn = accountConnection else { return }

        logger.error(
            "Settings account deletion coordinator missing on signed-in route source=\(source, privacy: .public)"
        )
        assertionFailure(
            "Settings account deletion coordinator is nil on a signed-in route (\(source))."
        )
    }
}
#endif
