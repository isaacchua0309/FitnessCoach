//
//  AppleHealthRemoteSyncSettingsView.swift
//  Fitness Coach
//
//  Forma — Remote health summary sync management (Settings → Apple Health).
//

import SwiftUI

struct AppleHealthRemoteSyncSettingsView: View {

    @ObservedObject var viewModel: AppleHealthSettingsViewModel
    let healthSyncStateStore: HealthSyncStateStore
    let settingsEnvironment: AppleHealthSettingsEnvironment

    @State private var showsDeleteConfirmation = false

    private var presentation: AppleHealthRemoteSyncSettingsPresentation {
        viewModel.remoteSyncPresentation(
            healthSyncStateStore: healthSyncStateStore,
            isHealthDataAvailable: settingsEnvironment.permissionService.isHealthDataAvailable,
            isRemoteSyncEnabled: settingsEnvironment.remoteSyncEnabled()
        )
    }

    var body: some View {
        formaSettingsDetailScreen {
            VStack(alignment: .leading, spacing: SettingsChromeAccessibility.detailSectionSpacing) {
                Text(presentation.intro)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)

                sectionCard(title: FormaProductCopy.Settings.AppleHealth.RemoteSync.statusLabel) {
                    detailRows(presentation.detailRows)
                }

                actionButton(
                    title: presentation.syncNowActionTitle,
                    isEnabled: presentation.isSyncNowEnabled,
                    isDestructive: false
                ) {
                    Task {
                        await viewModel.syncRemoteSummariesNow(environment: settingsEnvironment)
                    }
                }

                actionButton(
                    title: presentation.deleteActionTitle,
                    isEnabled: presentation.isDeleteEnabled,
                    isDestructive: true
                ) {
                    showsDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(presentation.screenTitle)
        .confirmationDialog(
            presentation.deleteConfirmationTitle,
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(presentation.deleteConfirmActionTitle, role: .destructive) {
                Task {
                    await viewModel.deleteRemoteSummaries(environment: settingsEnvironment)
                }
            }
            Button(FormaProductCopy.Common.cancel, role: .cancel) {}
        } message: {
            Text(presentation.deleteConfirmationMessage)
        }
        .formaThemeReactive()
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)
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
                    Divider()
                        .overlay(FormaTokens.Color.border)
                        .padding(.vertical, FormaTokens.Spacing.xs)
                }
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
                    Text(row.label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .frame(
                            width: SettingsChromeAccessibility.connectionLabelColumnWidth,
                            alignment: .leading
                        )
                        .fixedSize(horizontal: false, vertical: true)

                    Text(row.value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
        }
    }

    private func actionButton(
        title: String,
        isEnabled: Bool,
        isDestructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.medium))
                .foregroundStyle(
                    isEnabled
                        ? (isDestructive ? FormaTokens.Color.destructive : FormaTokens.Color.accent)
                        : FormaTokens.Color.textTertiary
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: SettingsChromeAccessibility.minimumActionButtonHeight)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                .fill(FormaTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                        .stroke(FormaTokens.Color.border, lineWidth: 1)
                )
        )
        .disabled(!isEnabled)
    }
}
