//
//  AppleHealthIntegrationView.swift
//  Fitness Coach
//
//  Forma — Settings destination for Apple Health permissions and sync.
//

import SwiftUI

struct AppleHealthIntegrationView: View {

    @ObservedObject var insightsStore: TrainingInsightsStore
    @EnvironmentObject private var healthSyncStateStore: HealthSyncStateStore
    @EnvironmentObject private var consentStore: HealthSummarySyncConsentStore
    @Environment(\.appleHealthSettingsEnvironment) private var settingsEnvironment
    @Environment(\.theme) private var theme

    @StateObject private var viewModel: AppleHealthSettingsViewModel
    @State private var didInitialLoad = false

    init(insightsStore: TrainingInsightsStore) {
        self.insightsStore = insightsStore
        _viewModel = StateObject(wrappedValue: AppleHealthSettingsViewModel(insightsStore: insightsStore))
    }

    private var presentation: AppleHealthSettingsPresentation {
        viewModel.presentation(
            healthSyncStateStore: healthSyncStateStore,
            consentStore: consentStore,
            isHealthDataAvailable: settingsEnvironment.permissionService.isHealthDataAvailable,
            isRemoteSyncCapabilityEnabled: settingsEnvironment.isRemoteSyncCapabilityEnabled
        )
    }

    private var remoteSyncPresentation: AppleHealthRemoteSyncSettingsPresentation {
        viewModel.remoteSyncPresentation(
            healthSyncStateStore: healthSyncStateStore,
            consentStore: consentStore,
            isHealthDataAvailable: settingsEnvironment.permissionService.isHealthDataAvailable,
            isRemoteSyncCapabilityEnabled: settingsEnvironment.isRemoteSyncCapabilityEnabled
        )
    }

    var body: some View {
        formaSettingsDetailScreen {
            content
        }
        .navigationTitle(presentation.screenTitle)
        .navigationDestination(isPresented: $viewModel.showsRemoteSyncSettings) {
            AppleHealthRemoteSyncSettingsView(
                viewModel: viewModel,
                consentStore: consentStore,
                healthSyncStateStore: healthSyncStateStore,
                settingsEnvironment: settingsEnvironment
            )
        }
        .confirmationDialog(
            remoteSyncPresentation.deleteConfirmationTitle,
            isPresented: $viewModel.showsDeleteRemoteConfirmation,
            titleVisibility: .visible
        ) {
            Button(remoteSyncPresentation.deleteConfirmActionTitle, role: .destructive) {
                Task {
                    await viewModel.deleteRemoteSummaries(
                        environment: settingsEnvironment,
                        consentStore: consentStore
                    )
                }
            }
            Button(FormaProductCopy.Common.cancel, role: .cancel) {}
        } message: {
            Text(remoteSyncPresentation.deleteConfirmationMessage)
        }
        .refreshable {
            await viewModel.loadSnapshot(
                healthSyncStateStore: healthSyncStateStore,
                consentStore: consentStore,
                environment: settingsEnvironment
            )
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await viewModel.loadSnapshot(
                healthSyncStateStore: healthSyncStateStore,
                consentStore: consentStore,
                environment: settingsEnvironment
            )
        }
        .formaThemeReactive()
    }

    @ViewBuilder
    private var content: some View {
        if presentation.showsLoadingState {
            loadingSection
        } else {
            VStack(alignment: .leading, spacing: SettingsChromeAccessibility.detailSectionSpacing) {
                if let emptyStateMessage = presentation.emptyStateMessage {
                    emptyStateSection(emptyStateMessage)
                }

                if let errorMessage = presentation.errorMessage {
                    errorSection(errorMessage)
                }

                heroSection
                privacySection
                healthDataDetailsSection
                permissionsSection
                actionsSection
            }
        }
    }

    // MARK: - States

    private var loadingSection: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            ProgressView()
                .tint(theme.accent)
            Text(FormaProductCopy.Loading.settings)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FormaTokens.Spacing.xl)
    }

    private func emptyStateSection(_ message: String) -> some View {
        Text(message)
            .font(FormaTokens.Typography.sectionSubtitle)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(message)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.warning)
                .fixedSize(horizontal: false, vertical: true)

            Button(FormaProductCopy.Common.tryAgain) {
                Task {
                    await viewModel.loadSnapshot(
                        healthSyncStateStore: healthSyncStateStore,
                        consentStore: consentStore,
                        environment: settingsEnvironment
                    )
                }
            }
            .font(FormaTokens.Typography.body.weight(.medium))
            .foregroundStyle(theme.accent)
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        Text(presentation.heroStatus)
            .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
            .foregroundStyle(
                presentation.heroShowsConnected
                    ? theme.success
                    : theme.primaryText
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            ForEach(presentation.privacyBullets, id: \.self) { line in
                Text(line)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(theme.secondaryText.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(HealthPrivacyCopy.Principles.overviewAccessibilityLabel)
    }

    private var healthDataDetailsSection: some View {
        sectionCard(title: presentation.healthDataDetailsTitle) {
            detailRows(presentation.healthDataDetailRows)
        }
    }

    private var permissionsSection: some View {
        sectionCard(title: presentation.permissionsSectionTitle) {
            VStack(spacing: 0) {
                ForEach(Array(presentation.permissionRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        rowDivider
                    }
                    permissionRow(row)
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(presentation.actions) { action in
                actionButton(action)
            }
        }
    }

    // MARK: - Rows

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            FormaPlanCard(compact: true) {
                content()
            }
        }
    }

    private func detailRows(_ rows: [AppleHealthSettingsConnectionRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    rowDivider
                }
                detailRow(label: row.label, value: row.value)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.secondaryText)
                .frame(
                    width: SettingsChromeAccessibility.connectionLabelColumnWidth,
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
    }

    private func permissionRow(_ row: AppleHealthSettingsPermissionRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
            Text(row.title)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(row.statusLabel)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(statusColor(for: row.status))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.statusLabel)")
    }

    private var rowDivider: some View {
        Divider()
            .overlay(theme.inputBorder)
            .padding(.vertical, FormaTokens.Spacing.xs)
    }

    private func statusColor(for status: AppleHealthSettingsPermissionDisplayStatus) -> Color {
        switch status {
        case .connected:
            return theme.success
        case .notShared, .unknown:
            return theme.tertiaryText
        case .denied:
            return theme.warning
        case .unavailable:
            return theme.secondaryText
        }
    }

    // MARK: - Actions

    private func actionButton(_ action: AppleHealthSettingsActionModel) -> some View {
        Button {
            Task { await handleAction(action) }
        } label: {
            Text(action.title)
                .font(FormaTokens.Typography.body.weight(.medium))
                .foregroundStyle(actionTitleColor(for: action))
                .frame(maxWidth: .infinity)
                .frame(minHeight: SettingsChromeAccessibility.minimumActionButtonHeight)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
        )
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(action.accessibilityHint ?? "")
    }

    private func actionTitleColor(for action: AppleHealthSettingsActionModel) -> Color {
        guard action.isEnabled else {
            return theme.tertiaryText
        }
        if action.isDestructive {
            return theme.destructive
        }
        return theme.accent
    }

    private func handleAction(_ action: AppleHealthSettingsActionModel) async {
        switch action.kind {
        case .connectAppleHealth:
            await viewModel.connectAppleHealth(
                healthSyncStateStore: healthSyncStateStore,
                consentStore: consentStore,
                environment: settingsEnvironment
            )
        case .refreshHealthData:
            await viewModel.refreshHealthData(
                healthSyncStateStore: healthSyncStateStore,
                consentStore: consentStore,
                environment: settingsEnvironment
            )
        case .manageInAppleHealth:
            HealthAppSettingsNavigator.openHealthPermissions()
        case .manageHealthDataSync:
            viewModel.showsRemoteSyncSettings = true
        case .deleteRemoteHealthSummaries:
            viewModel.showsDeleteRemoteConfirmation = true
        }
    }
}
