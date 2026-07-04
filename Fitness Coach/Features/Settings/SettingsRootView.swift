//
//  SettingsRootView.swift
//  Fitness Coach
//
//  Forma — Consumer settings hub (grouped list, modal Done).
//

import SwiftUI

struct SettingsRootView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.settingsAnalyticsCoordinator) private var analyticsCoordinator
    @EnvironmentObject private var insightsStore: TrainingInsightsStore
    @EnvironmentObject private var themeStore: ThemeStore

    @Binding var formState: PlanFormState
    let errorMessage: String?
    let onSaveUnits: (PlanFormState) async -> Void
    let onDismiss: () -> Void

    var featureAvailability: SettingsFeatureAvailability = .production
    var supportConfiguration: SettingsSupportConfiguration = .production
    var isDebugOrInternalBuild: Bool = FormaBuildConfiguration.isDebugOrInternalBuild
    var bodyDetailsInput: BodyDetailsSettingsPresentationInput?
    var onUpdateInPlan: (() -> Void)?

    @State private var showsDeleteDataConfirmation = false
    @State private var showsDeleteUnavailableAlert = false
    @State private var supportMailTopic: SettingsSupportMailTopic?

    private var resolvedBodyDetailsInput: BodyDetailsSettingsPresentationInput {
        bodyDetailsInput ?? BodyDetailsSettingsPresentationInput(formState: formState)
    }

    private var presentationState: SettingsPresentationState {
        SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: insightsStore.integrationState,
                unitSystem: formState.unitSystem,
                themePalette: themeStore.palette,
                appVersion: FormaAppMetadata.versionDisplayString(),
                featureAvailability: featureAvailability,
                legalAvailability: .production,
                supportConfiguration: supportConfiguration,
                isDebugOrInternalBuild: isDebugOrInternalBuild
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                section(presentationState.account)
                section(presentationState.preferences)
                section(presentationState.integrations)
                    .task {
                        await insightsStore.refresh()
                    }
                section(presentationState.privacyData)
                if let support = presentationState.support {
                    section(support)
                }
                section(presentationState.about)

                if let developer = presentationState.developer {
                    section(developer)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.warning)
                            .formaSettingsRowChrome()
                    }
                }
            }
            .formaGroupedList()
            .navigationTitle(FormaProductCopy.Settings.Hub.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(FormaProductCopy.Common.done) {
                        onDismiss()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(FormaTokens.Color.accent)
                    .accessibilityLabel(FormaProductCopy.Settings.Hub.doneAccessibilityLabel)
                }
            }
            .formaScrollBottomInset()
            .onAppear {
                analyticsCoordinator.updateContext(
                    unitSystem: formState.unitSystem,
                    themePalette: themeStore.palette,
                    integrationState: insightsStore.integrationState
                )
                analyticsCoordinator.logSettingsViewed()
            }
            .confirmationDialog(
                deleteDataPresentation.confirmationTitle,
                isPresented: $showsDeleteDataConfirmation,
                titleVisibility: .visible
            ) {
                Button(deleteDataPresentation.confirmActionTitle, role: .destructive) {
                    let result = SettingsDeleteDataActionHandler.perform()
                    if case .notImplemented = result {
                        showsDeleteUnavailableAlert = true
                    }
                }
                Button(FormaProductCopy.Common.cancel, role: .cancel) {}
            } message: {
                Text(deleteDataPresentation.confirmationMessage)
            }
            .alert(
                deleteDataPresentation.unavailableTitle,
                isPresented: $showsDeleteUnavailableAlert
            ) {
                Button(FormaProductCopy.Common.ok, role: .cancel) {}
            } message: {
                Text(deleteDataPresentation.unavailableMessage)
            }
            .sheet(item: $supportMailTopic) { topic in
                #if canImport(MessageUI)
                if let email = supportConfiguration.supportEmail {
                    SettingsSupportMailComposer(
                        topic: topic,
                        supportEmail: email,
                        diagnostics: SettingsSupportDiagnosticsBuilder.build(),
                        onFinish: { supportMailTopic = nil }
                    )
                }
                #endif
            }
        }
    }

    private var deleteDataPresentation: SettingsDeleteDataPresentation {
        SettingsDeleteDataPresentationBuilder.build()
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(_ state: SettingsAccountSectionState) -> some View {
        section(title: state.title, footer: nil, rows: state.rows, sectionType: .account)
    }

    @ViewBuilder
    private func section(_ state: SettingsPreferencesSectionState) -> some View {
        section(title: state.title, footer: nil, rows: state.rows, sectionType: .preferences)
    }

    @ViewBuilder
    private func section(_ state: SettingsIntegrationsSectionState) -> some View {
        section(title: state.title, footer: nil, rows: state.rows, sectionType: .integrations)
    }

    @ViewBuilder
    private func section(_ state: SettingsPrivacyDataSectionState) -> some View {
        section(title: state.title, footer: state.footer, rows: state.rows, sectionType: .privacyData)
    }

    @ViewBuilder
    private func section(_ state: SettingsSupportSectionState) -> some View {
        section(title: state.title, footer: state.footer, rows: state.rows, sectionType: .support)
    }

    @ViewBuilder
    private func section(_ state: SettingsAboutSectionState) -> some View {
        section(title: state.title, footer: nil, rows: state.rows, sectionType: .about)
    }

    @ViewBuilder
    private func section(_ state: SettingsDeveloperSectionState) -> some View {
        section(title: state.title, footer: state.footer, rows: state.rows, sectionType: .developer)
    }

    @ViewBuilder
    private func section(
        title: String,
        footer: String?,
        rows: [SettingsRowPresentation],
        sectionType: SettingsAnalyticsSectionType
    ) -> some View {
        Section {
            ForEach(rows) { row in
                rowView(row, sectionType: sectionType)
            }
        } header: {
            FormaSettingsSectionHeader(title: title)
        } footer: {
            if let footer {
                Text(footer)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: SettingsRowPresentation, sectionType: SettingsAnalyticsSectionType) -> some View {
        if case .supportMail(let topic) = row.destination {
            settingsButtonRow(
                row: row,
                showsDisclosure: true,
                disclosureSystemName: "envelope",
                accessibilityHint: "Opens mail composer"
            ) {
                analyticsCoordinator.logSupportTapped(topic: topic, sectionType: sectionType)
                openSupportMail(topic)
            }
        } else if case .legalDocument(let document) = row.destination,
                  let url = presentationState.externalURL(for: document) {
            settingsButtonRow(
                row: row,
                showsDisclosure: true,
                disclosureSystemName: "arrow.up.right",
                accessibilityHint: SettingsRowAccessibilityFormatter.buttonHint(opensExternally: true)
            ) {
                logLegalDocumentTapped(document, sectionType: sectionType)
                openURL(url)
            }
        } else if case .deleteData = row.destination {
            settingsButtonRow(
                row: row,
                isDestructive: true,
                accessibilityHint: "Opens confirmation"
            ) {
                analyticsCoordinator.logRowTapped(rowID: row.id, sectionType: sectionType)
                showsDeleteDataConfirmation = true
            }
        } else if case .exportData = row.destination {
            settingsButtonRow(
                row: row,
                showsDisclosure: true,
                accessibilityHint: SettingsRowAccessibilityFormatter.buttonHint(opensExternally: false)
            ) {
                analyticsCoordinator.logRowTapped(rowID: row.id, sectionType: sectionType)
                handleExportData()
            }
        } else if row.isNavigable, let destination = row.destination {
            NavigationLink {
                destinationView(for: destination, sectionType: sectionType)
            } label: {
                FormaSettingsRowLabel(title: row.title, status: row.status)
            }
            .formaSettingsRowChrome()
            .accessibilityLabel(SettingsRowAccessibilityFormatter.label(title: row.title, status: row.status))
            .accessibilityHint(SettingsRowAccessibilityFormatter.buttonHint(opensExternally: false))
            .simultaneousGesture(
                TapGesture().onEnded {
                    analyticsCoordinator.logRowTapped(rowID: row.id, sectionType: sectionType)
                }
            )
        } else {
            FormaSettingsRowLabel(title: row.title, status: row.status)
                .formaSettingsRowChrome(isEnabled: false)
                .accessibilityLabel(SettingsRowAccessibilityFormatter.label(title: row.title, status: row.status))
        }
    }

    private func settingsButtonRow(
        row: SettingsRowPresentation,
        showsDisclosure: Bool = false,
        disclosureSystemName: String = "chevron.right",
        isDestructive: Bool = false,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: isDestructive ? .destructive : nil, action: action) {
            FormaSettingsRowLabel(
                title: row.title,
                status: row.status,
                showsDisclosure: showsDisclosure,
                disclosureSystemName: disclosureSystemName,
                isDestructive: isDestructive
            )
        }
        .formaSettingsRowChrome()
        .accessibilityLabel(SettingsRowAccessibilityFormatter.label(title: row.title, status: row.status))
        .accessibilityHint(accessibilityHint ?? "")
    }

    @ViewBuilder
    private func destinationView(
        for destination: SettingsRowDestination,
        sectionType: SettingsAnalyticsSectionType
    ) -> some View {
        switch destination {
        case .account:
            AccountSettingsView()
                .onAppear { analyticsCoordinator.logAccountViewed() }
        case .units:
            UnitsSettingsScreen(
                formState: $formState,
                onSave: onSaveUnits
            )
            .onAppear { analyticsCoordinator.logUnitsSettingsViewed() }
        case .bodyAndStats:
            PlanBodyDetailsSettingsView(
                presentation: BodyDetailsSettingsPresentationBuilder.build(
                    input: resolvedBodyDetailsInput
                ),
                onUpdateInPlan: {
                    onUpdateInPlan?()
                }
            )
            .onAppear { analyticsCoordinator.logBodyStatsViewed() }
        case .theme:
            ThemeSettingsView()
                .onAppear { analyticsCoordinator.logThemeSettingsViewed() }
        case .appleHealthIntegration:
            AppleHealthIntegrationView(insightsStore: insightsStore)
                .onAppear { analyticsCoordinator.logAppleHealthSettingsViewed() }
        case .legalDocument(let document):
            SettingsLegalDocumentView(document: document)
                .onAppear {
                    switch document {
                    case .privacyPolicy:
                        analyticsCoordinator.logPrivacyPolicyTapped(sectionType: sectionType)
                    case .terms:
                        analyticsCoordinator.logTermsTapped(sectionType: sectionType)
                    }
                }
        case .supportMail:
            EmptyView()
        case .exportData, .deleteData:
            EmptyView()
        case .authDiagnostics, .pipelineTraces:
            developerDestinationView(for: destination)
        case .healthIntelligenceSnapshot:
            developerDestinationView(for: destination)
        case .coachContextInspector:
            developerDestinationView(for: destination)
        case .accountSyncDiagnostics:
            developerDestinationView(for: destination)
        }
    }

    @ViewBuilder
    private func developerDestinationView(for destination: SettingsRowDestination) -> some View {
        if presentationState.isDebugOrInternalBuild,
           FormaAbTest.Settings.developerSectionVisible,
           FormaBuildConfiguration.includesCompiledDeveloperTools {
            switch destination {
            case .authDiagnostics:
                AuthDiagnosticsView()
            case .pipelineTraces:
                PipelineDiagnosticsView()
            case .healthIntelligenceSnapshot:
                HealthIntelligenceDiagnosticsView()
            case .coachContextInspector:
                CoachContextInspectorView()
            case .accountSyncDiagnostics:
                AccountSyncDiagnosticsView()
            default:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    private func logLegalDocumentTapped(
        _ document: FormaLegalDocument,
        sectionType: SettingsAnalyticsSectionType
    ) {
        switch document {
        case .privacyPolicy:
            analyticsCoordinator.logPrivacyPolicyTapped(sectionType: sectionType)
            analyticsCoordinator.logRowTapped(rowID: .privacyPolicy, sectionType: sectionType)
        case .terms:
            analyticsCoordinator.logTermsTapped(sectionType: sectionType)
            analyticsCoordinator.logRowTapped(rowID: .termsOfService, sectionType: sectionType)
        }
    }

    private func openSupportMail(_ topic: SettingsSupportMailTopic) {
        guard let email = supportConfiguration.supportEmail else { return }
        let diagnostics = SettingsSupportDiagnosticsBuilder.build()

        if SettingsSupportMailComposerCapability.canSendMail {
            supportMailTopic = topic
            return
        }

        guard let url = SettingsSupportMailURLBuilder.url(
            for: topic,
            supportEmail: email,
            diagnostics: diagnostics
        ) else { return }
        openURL(url)
    }

    private func handleExportData() {
        _ = SettingsExportDataActionHandler.perform()
    }
}
