//
//  SettingsDeveloperPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Developer settings section presentation.
//

import Foundation

enum SettingsDeveloperPresentationBuilder {

    static func buildSection(isVisible: Bool) -> SettingsDeveloperSectionState? {
        guard isVisible else { return nil }

        var rows: [SettingsRowPresentation] = [
            row(
                id: .authDiagnostics,
                title: FormaProductCopy.Settings.Rows.authDiagnostics,
                destination: .authDiagnostics
            ),
            row(
                id: .pipelineTraces,
                title: FormaProductCopy.Settings.Rows.pipelineTraces,
                destination: .pipelineTraces
            ),
            row(
                id: .healthIntelligenceSnapshot,
                title: FormaProductCopy.Settings.Rows.healthIntelligenceSnapshot,
                destination: .healthIntelligenceSnapshot
            ),
            row(
                id: .coachContextInspector,
                title: FormaProductCopy.Settings.Rows.coachContextInspector,
                destination: .coachContextInspector
            ),
            row(
                id: .accountSyncDiagnostics,
                title: FormaProductCopy.Settings.Rows.accountSyncDiagnostics,
                destination: .accountSyncDiagnostics
            ),
            row(
                id: .accountRestoreDiagnostics,
                title: FormaProductCopy.Settings.Rows.accountRestoreDiagnostics,
                destination: .accountRestoreDiagnostics
            )
        ]
        #if DEBUG
        rows.append(
            row(
                id: .contextLoopReport,
                title: FormaProductCopy.Settings.Rows.contextLoopReport,
                destination: .contextLoopReport
            )
        )
        #endif

        return SettingsDeveloperSectionState(
            title: FormaProductCopy.Settings.Hub.developerSectionTitle,
            rows: rows,
            footer: FormaProductCopy.Settings.Developer.sectionFooter
        )
    }

    private static func row(
        id: SettingsRowID,
        title: String,
        destination: SettingsRowDestination
    ) -> SettingsRowPresentation {
        SettingsRowPresentation(
            id: id,
            title: title,
            status: nil,
            destination: destination,
            isEnabled: true
        )
    }
}
