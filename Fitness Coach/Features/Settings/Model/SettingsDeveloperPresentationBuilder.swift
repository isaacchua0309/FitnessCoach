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

        return SettingsDeveloperSectionState(
            title: FormaProductCopy.Settings.Hub.developerSectionTitle,
            rows: [
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
                )
            ],
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
