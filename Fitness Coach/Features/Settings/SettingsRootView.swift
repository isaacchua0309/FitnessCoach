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
    @EnvironmentObject private var insightsStore: TrainingInsightsStore

    @Binding var formState: PlanFormState
    let errorMessage: String?
    let onSaveUnits: (PlanFormState) async -> Void
    let onDismiss: () -> Void

    var featureAvailability: SettingsFeatureAvailability = .production
    var isDebugOrInternalBuild: Bool = FormaBuildConfiguration.isDebugOrInternalBuild

    private var presentationState: SettingsPresentationState {
        SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: insightsStore.integrationState,
                appVersionDisplay: FormaAppMetadata.versionDisplayString(),
                featureAvailability: featureAvailability,
                isDebugOrInternalBuild: isDebugOrInternalBuild
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                sectionView(presentationState.account)
                sectionView(presentationState.preferences)
                sectionView(presentationState.integrations)
                    .task {
                        await insightsStore.refresh()
                    }
                sectionView(presentationState.privacyData)
                sectionView(presentationState.support)
                sectionView(presentationState.about)

                if let developer = presentationState.developer {
                    sectionView(developer)
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
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func sectionView(_ section: SettingsAccountSectionState) -> some View {
        sectionView(title: section.title, footer: nil, rows: section.rows)
    }

    @ViewBuilder
    private func sectionView(_ section: SettingsPreferencesSectionState) -> some View {
        sectionView(title: section.title, footer: nil, rows: section.rows)
    }

    @ViewBuilder
    private func sectionView(_ section: SettingsIntegrationsSectionState) -> some View {
        sectionView(title: section.title, footer: nil, rows: section.rows)
    }

    @ViewBuilder
    private func sectionView(_ section: SettingsPrivacyDataSectionState) -> some View {
        sectionView(title: section.title, footer: nil, rows: section.rows)
    }

    @ViewBuilder
    private func sectionView(_ section: SettingsSupportSectionState) -> some View {
        sectionView(title: section.title, footer: nil, rows: section.rows)
    }

    @ViewBuilder
    private func sectionView(_ section: SettingsAboutSectionState) -> some View {
        sectionView(title: section.title, footer: nil, rows: section.rows)
    }

    @ViewBuilder
    private func sectionView(_ section: SettingsDeveloperSectionState) -> some View {
        sectionView(title: section.title, footer: section.footer, rows: section.rows)
    }

    @ViewBuilder
    private func sectionView(
        title: String,
        footer: String?,
        rows: [SettingsRowPresentation]
    ) -> some View {
        Section {
            ForEach(rows) { row in
                rowView(row)
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
    private func rowView(_ row: SettingsRowPresentation) -> some View {
        if case .supportMail(let topic) = row.destination {
            Button {
                openSupportMail(topic)
            } label: {
                FormaSettingsRowLabel(
                    title: row.title,
                    subtitle: row.subtitle,
                    status: row.status
                )
            }
            .formaSettingsRowChrome()
        } else if row.isNavigable, let destination = row.destination {
            NavigationLink {
                destinationView(for: destination)
            } label: {
                FormaSettingsRowLabel(
                    title: row.title,
                    subtitle: row.subtitle,
                    status: row.status
                )
            }
            .formaSettingsRowChrome()
        } else {
            FormaSettingsRowLabel(
                title: row.title,
                subtitle: row.subtitle,
                status: row.status
            )
            .formaSettingsRowChrome(isEnabled: false)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: SettingsRowDestination) -> some View {
        switch destination {
        case .account:
            AccountSettingsView()
        case .units:
            UnitsSettingsScreen(
                formState: $formState,
                onSave: onSaveUnits
            )
        case .bodyAndStats:
            PlanBodyDetailsSettingsView(formState: formState)
        case .theme:
            ThemeSettingsView()
        case .appleHealthIntegration:
            AppleHealthIntegrationView(insightsStore: insightsStore)
        case .legalDocument(let document):
            SettingsLegalDocumentView(document: document)
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

    private func openSupportMail(_ topic: SettingsSupportMailTopic) {
        guard let url = SettingsSupportMailURLBuilder.url(for: topic) else { return }
        openURL(url)
    }
}

#Preview {
    SettingsRootView(
        formState: .constant(PlanPreviewData.formState),
        errorMessage: nil,
        onSaveUnits: { _ in },
        onDismiss: {}
    )
    .environmentObject(AuthManager())
    .environmentObject(
        TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .connected)
        )
    )
    .environmentObject(ThemeStore(userDefaults: UserDefaults(suiteName: "SettingsRootPreview")!))
    .formaThemePreview()
}
