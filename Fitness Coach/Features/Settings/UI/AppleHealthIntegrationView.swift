//
//  AppleHealthIntegrationView.swift
//  Fitness Coach
//
//  Forma — Settings destination for Apple Health training access.
//

import SwiftUI

struct AppleHealthIntegrationView: View {

    @ObservedObject var insightsStore: TrainingInsightsStore

    private var presentation: AppleHealthSettingsPresentation {
        AppleHealthSettingsPresentationBuilder.build(
            input: AppleHealthSettingsPresentationInput(
                integrationState: insightsStore.integrationState,
                lastSyncDate: insightsStore.lastSyncedAt
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                heroSection
                trustCopySection
                connectionCard
                primaryActionSection
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, FormaTokens.Spacing.sm)
        }
        .formaScreenBackground()
        .navigationTitle(presentation.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
        .task {
            await insightsStore.refresh()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        Text(presentation.heroStatus)
            .font(FormaTokens.Typography.screenTitle)
            .foregroundStyle(
                presentation.heroShowsConnected
                    ? FormaTokens.Color.success
                    : FormaTokens.Color.textPrimary
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Trust copy

    private var trustCopySection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            ForEach(presentation.trustCopy, id: \.self) { line in
                Text(line)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Connection card

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(presentation.connectionCardTitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)

            FormaPlanCard {
                VStack(spacing: 0) {
                    ForEach(Array(presentation.connectionRows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            connectionRowDivider
                        }
                        connectionRow(row)
                    }
                }
            }
        }
    }

    private func connectionRow(_ row: AppleHealthSettingsConnectionRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
            Text(row.label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(width: 88, alignment: .leading)

            Text(row.value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
    }

    private var connectionRowDivider: some View {
        Divider()
            .overlay(FormaTokens.Color.border)
            .padding(.vertical, FormaTokens.Spacing.xs)
    }

    // MARK: - Primary action

    @ViewBuilder
    private var primaryActionSection: some View {
        if let title = presentation.primaryActionTitle {
            Button {
                Task { await handlePrimaryAction() }
            } label: {
                Text(title)
                    .font(FormaTokens.Typography.body.weight(.medium))
                    .foregroundStyle(
                        presentation.isPrimaryActionEnabled
                            ? FormaTokens.Color.accent
                            : FormaTokens.Color.textTertiary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: FormaTokens.Layout.minTouchTarget)
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
            .disabled(!presentation.isPrimaryActionEnabled)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(presentation.primaryActionAccessibilityHint ?? "")
        }
    }

    private func handlePrimaryAction() async {
        await AppleHealthSettingsActionHandler.perform(
            action: presentation.primaryAction,
            openHealthApp: openHealthAccessSettings,
            connect: { await insightsStore.connectAppleHealth() }
        )
    }

    private func openHealthAccessSettings() {
        HealthAppSettingsNavigator.openHealthPermissions()
    }
}
