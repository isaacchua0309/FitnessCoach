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
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(FormaTokens.Color.accent)
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
    private func section(_ section: SettingsAccountSectionState) -> some View {
        section(title: section.title, footer: nil, rows: section.rows, sectionType: .account)
    }

    @ViewBuilder
    private func section(_ section: SettingsPreferencesSectionState) -> some View {
        section(title: section.title, footer: nil, rows: section.rows, sectionType: .preferences)
    }

    @ViewBuilder
    private func section(_ section: SettingsIntegrationsSectionState) -> some View {
        section(title: section.title, footer: nil, rows: section.rows, sectionType: .integrations)
    }

    @ViewBuilder
    private func section(_ section: SettingsPrivacyDataSectionState) -> some View {
        section(title: section.title, footer: section.footer, rows: section.rows, sectionType: .privacyData)
    }

    @ViewBuilder
    private func section(_ section: SettingsSupportSectionState) -> some View {
        section(title: section.title, footer: section.footer, rows: section.rows, sectionType: .support)
    }

    @ViewBuilder
    private func section(_ section: SettingsAboutSectionState) -> some View {
        section(title: section.title, footer: nil, rows: section.rows, sectionType: .about)
    }

    @ViewBuilder
    private func section(_ section: SettingsDeveloperSectionState) -> some View {
        section(title: section.title, footer: section.footer, rows: section.rows, sectionType: .developer)
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
            Button {
                analyticsCoordinator.logSupportTapped(topic: topic, sectionType: sectionType)
                openSupportMail(topic)
            } label: {
                FormaSettingsRowLabel(title: row.title, status: row.status)
            }
            .formaSettingsRowChrome()
        } else if case .legalDocument(let document) = row.destination,
                  let url = presentationState.externalURL(for: document) {
            Button {
                logLegalDocumentTapped(document, sectionType: sectionType)
                openURL(url)
            } label: {
                FormaSettingsRowLabel(title: row.title, status: row.status)
            }
            .formaSettingsRowChrome()
        } else if case .deleteData = row.destination {
            Button(role: .destructive) {
                analyticsCoordinator.logRowTapped(rowID: row.id, sectionType: sectionType)
                showsDeleteDataConfirmation = true
            } label: {
                FormaSettingsRowLabel(title: row.title, status: row.status)
            }
            .formaSettingsRowChrome()
        } else if case .exportData = row.destination {
            Button {
                analyticsCoordinator.logRowTapped(rowID: row.id, sectionType: sectionType)
                handleExportData()
            } label: {
                FormaSettingsRowLabel(title: row.title, status: row.status)
            }
            .formaSettingsRowChrome()
        } else if row.isNavigable, let destination = row.destination {
            NavigationLink {
                destinationView(for: destination, sectionType: sectionType)
            } label: {
                FormaSettingsRowLabel(title: row.title, status: row.status)
            }
            .formaSettingsRowChrome()
            .simultaneousGesture(
                TapGesture().onEnded {
                    analyticsCoordinator.logRowTapped(rowID: row.id, sectionType: sectionType)
                }
            )
        } else {
            FormaSettingsRowLabel(title: row.title, status: row.status)
                .formaSettingsRowChrome(isEnabled: false)
        }
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
        case .authDiagnostics:
            #if DEBUG
            AuthDiagnosticsView()
            #else
            EmptyView()
            #endif
        case .pipelineTraces:
            #if DEBUG
            PipelineDiagnosticsView()
            #else
            EmptyView()
            #endif
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
