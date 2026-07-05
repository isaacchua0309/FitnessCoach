//
//  SettingsPrivacyDataPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Privacy & Data settings section rows and detail presentations.
//

import Foundation

struct SettingsPrivacyDataPresentationInput: Equatable, Sendable {
    let status: SettingsPrivacyDataStatusSnapshot
    let featureAvailability: SettingsFeatureAvailability
    let legalAvailability: SettingsLegalAvailability
    let accountDeletionWiring: SettingsAccountDeletionWiring

    init(
        status: SettingsPrivacyDataStatusSnapshot,
        featureAvailability: SettingsFeatureAvailability,
        legalAvailability: SettingsLegalAvailability,
        accountDeletionWiring: SettingsAccountDeletionWiring? = nil
    ) {
        self.status = status
        self.featureAvailability = featureAvailability
        self.legalAvailability = legalAvailability
        self.accountDeletionWiring = accountDeletionWiring
            ?? SettingsAccountDeletionWiring(
                featureAvailability: featureAvailability,
                hasCoordinator: false
            )
    }
}

enum SettingsPrivacyDataPresentationBuilder {

    static func buildSection(
        input: SettingsPrivacyDataPresentationInput
    ) -> SettingsPrivacyDataSectionState {
        var rows: [SettingsRowPresentation] = []

        rows.append(
            row(
                id: .accountDataStatus,
                title: FormaProductCopy.Settings.Rows.accountDataStatus,
                status: accountDataStatusLabel(for: input.status),
                destination: .accountDataStatus
            )
        )

        rows.append(
            row(
                id: .syncStatus,
                title: FormaProductCopy.Settings.Rows.syncStatus,
                status: syncStatusLabel(for: input.status),
                destination: .syncStatus
            )
        )

        if input.accountDeletionWiring.showsDeleteLocalDeviceRow {
            rows.append(
                deletionRow(
                    id: .deleteLocalDeviceData,
                    title: FormaProductCopy.Settings.Rows.deleteLocalDeviceData,
                    destination: .deleteLocalDeviceData,
                    isActionable: input.accountDeletionWiring.canOpenDeleteLocalDeviceFlow
                )
            )
        }

        if input.accountDeletionWiring.showsDeleteAccountRow {
            rows.append(
                deletionRow(
                    id: .deleteAccount,
                    title: FormaProductCopy.Settings.Rows.deleteAccount,
                    destination: .deleteAccount,
                    isActionable: input.accountDeletionWiring.canOpenDeleteAccountFlow
                )
            )
        }

        rows.append(
            row(
                id: .healthDataNote,
                title: FormaProductCopy.Settings.Rows.healthDataNote,
                destination: .healthDataNote
            )
        )

        if input.featureAvailability.isDataExportEnabled {
            rows.append(
                row(
                    id: .exportData,
                    title: FormaProductCopy.Settings.Rows.exportAccountData,
                    destination: .exportData
                )
            )
        } else if input.featureAvailability.showsExportPlaceholder {
            rows.append(
                SettingsRowPresentation(
                    id: .exportData,
                    title: FormaProductCopy.Settings.Rows.exportAccountData,
                    status: FormaProductCopy.Settings.PrivacyData.exportUnavailableStatus,
                    destination: nil,
                    isEnabled: false
                )
            )
        }

        if input.legalAvailability.isPrivacyPolicyAvailable {
            rows.append(
                row(
                    id: .privacyPolicy,
                    title: FormaProductCopy.Settings.Rows.privacyPolicy,
                    destination: .legalDocument(.privacyPolicy)
                )
            )
        }

        return SettingsPrivacyDataSectionState(
            title: FormaProductCopy.Settings.Hub.privacyDataSectionTitle,
            rows: rows,
            footer: FormaProductCopy.Settings.PrivacyData.sectionFooter
        )
    }

    static func accountStatusPresentation(
        status: SettingsPrivacyDataStatusSnapshot
    ) -> SettingsPrivacyDataAccountStatusPresentation {
        let copy = FormaProductCopy.Settings.PrivacyData.self
        var rows: [SettingsPrivacyDataDetailRow] = [
            detailRow(
                id: "account",
                label: copy.accountStatusAccountLabel,
                value: accountConnectionLabel(for: status.accountConnection)
            )
        ]

        if case .signedIn(let provider) = status.accountConnection {
            rows.append(
                detailRow(
                    id: "sign_in_method",
                    label: copy.accountStatusSignInMethodLabel,
                    value: AccountSignInProviderLabels.signInMethod(for: provider)
                )
            )
        }

        rows.append(
            detailRow(
                id: "last_restore",
                label: copy.accountStatusLastRestoreLabel,
                value: SettingsPrivacyDataTimestampFormatter.format(status.lastSuccessfulRestoreAt)
            )
        )

        return SettingsPrivacyDataAccountStatusPresentation(
            screenTitle: copy.accountStatusScreenTitle,
            rows: rows
        )
    }

    static func syncStatusPresentation(
        status: SettingsPrivacyDataStatusSnapshot
    ) -> SettingsPrivacyDataSyncStatusPresentation {
        let copy = FormaProductCopy.Settings.PrivacyData.self
        return SettingsPrivacyDataSyncStatusPresentation(
            screenTitle: copy.syncStatusScreenTitle,
            rows: [
                detailRow(
                    id: "pending_uploads",
                    label: copy.syncStatusPendingUploadsLabel,
                    value: countLabel(status.pendingUploadCount)
                ),
                detailRow(
                    id: "last_sync",
                    label: copy.syncStatusLastSyncLabel,
                    value: SettingsPrivacyDataTimestampFormatter.format(status.lastSuccessfulSyncAt)
                ),
                detailRow(
                    id: "last_restore",
                    label: copy.syncStatusLastRestoreLabel,
                    value: SettingsPrivacyDataTimestampFormatter.format(status.lastSuccessfulRestoreAt)
                ),
                detailRow(
                    id: "restore_in_progress",
                    label: copy.syncStatusRestoreInProgressLabel,
                    value: status.isBlockingRestoreActive
                        ? copy.syncStatusYesValue
                        : copy.syncStatusNoValue
                )
            ]
        )
    }

    static func healthNotePresentation() -> SettingsPrivacyDataHealthNotePresentation {
        SettingsPrivacyDataHealthNotePresentation(
            screenTitle: FormaProductCopy.Settings.PrivacyData.healthDataNoteScreenTitle,
            bodyParagraphs: FormaProductCopy.Settings.PrivacyData.healthDataNoteBodyParagraphs
        )
    }

    // MARK: - Hub labels

    private static func accountDataStatusLabel(
        for status: SettingsPrivacyDataStatusSnapshot
    ) -> String {
        switch status.accountConnection {
        case .signedOut:
            return FormaProductCopy.Settings.PrivacyData.accountStatusSignedOut
        case .signedIn:
            return FormaProductCopy.Settings.PrivacyData.accountStatusSignedIn
        }
    }

    private static func syncStatusLabel(
        for status: SettingsPrivacyDataStatusSnapshot
    ) -> String {
        if status.pendingUploadCount > 0 {
            return FormaProductCopy.Settings.PrivacyData.syncStatusPendingCount(
                status.pendingUploadCount
            )
        }
        if let lastSync = status.lastSuccessfulSyncAt {
            return SettingsPrivacyDataTimestampFormatter.format(lastSync)
        }
        return FormaProductCopy.Settings.PrivacyData.syncStatusNotYetSynced
    }

    private static func accountConnectionLabel(
        for connection: SettingsPrivacyDataStatusSnapshot.AccountConnection
    ) -> String {
        switch connection {
        case .signedOut:
            return FormaProductCopy.Settings.PrivacyData.accountStatusSignedOut
        case .signedIn:
            return FormaProductCopy.Settings.PrivacyData.accountStatusSignedIn
        }
    }

    private static func countLabel(_ count: Int) -> String {
        FormaProductCopy.Settings.PrivacyData.countLabel(count)
    }

    // MARK: - Row factory

    private static func row(
        id: SettingsRowID,
        title: String,
        status: String? = nil,
        destination: SettingsRowDestination?
    ) -> SettingsRowPresentation {
        SettingsRowPresentation(
            id: id,
            title: title,
            status: status,
            destination: destination,
            isEnabled: destination != nil
        )
    }

    private static func deletionRow(
        id: SettingsRowID,
        title: String,
        destination: SettingsRowDestination,
        isActionable: Bool
    ) -> SettingsRowPresentation {
        guard isActionable else {
            return SettingsRowPresentation(
                id: id,
                title: title,
                status: FormaProductCopy.Settings.PrivacyData.deletionCoordinatorUnavailableStatus,
                destination: nil,
                isEnabled: false
            )
        }

        return row(
            id: id,
            title: title,
            destination: destination
        )
    }

    private static func detailRow(
        id: String,
        label: String,
        value: String
    ) -> SettingsPrivacyDataDetailRow {
        SettingsPrivacyDataDetailRow(id: id, label: label, value: value)
    }
}
