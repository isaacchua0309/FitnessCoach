//
//  AppleHealthIntegrationView.swift
//  Fitness Coach
//
//  Forma — Settings destination for Apple Health training access.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AppleHealthIntegrationView: View {

    @ObservedObject var insightsStore: TrainingInsightsStore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(TrainingIntegrationCopy.healthIntegrationTitle)
                        .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)

                    Text(TrainingIntegrationCopy.healthIntegrationBody)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textLegal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .fitPilotSettingsRowChrome()
            }

            Section {
                FitPilotPlanDisplayRow(
                    label: "Status",
                    value: TrainingIntegrationCopy.settingsStatusLabel(
                        for: insightsStore.integrationState
                    ),
                    multilineValue: false
                )
                .fitPilotSettingsRowChrome()

                FitPilotPlanDisplayRow(
                    label: "Details",
                    value: TrainingIntegrationCopy.settingsDetailDescription(
                        for: insightsStore.integrationState
                    ),
                    multilineValue: true
                )
                .fitPilotSettingsRowChrome()
            } header: {
                FitPilotSettingsSectionHeader(title: "Connection")
            }

            if let actionTitle = primaryActionTitle {
                Section {
                    Button {
                        Task { await handlePrimaryAction() }
                    } label: {
                        settingsRowLabel(actionTitle)
                    }
                    .fitPilotSettingsRowChrome()
                    .disabled(insightsStore.integrationState.isRequestingPermission)
                }
            }

            if showsManageAccess {
                Section {
                    Button {
                        openHealthAccessSettings()
                    } label: {
                        settingsRowLabel(TrainingIntegrationCopy.manageHealthAccess)
                    }
                    .fitPilotSettingsRowChrome()
                } footer: {
                    Text(TrainingIntegrationCopy.healthIntegrationFooter)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                }
            }
        }
        .fitPilotDarkGroupedList()
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await insightsStore.refresh()
        }
    }

    private var primaryActionTitle: String? {
        TrainingIntegrationCopy.connectButtonTitle(for: insightsStore.integrationState)
    }

    private var showsManageAccess: Bool {
        switch insightsStore.integrationState {
        case .connected, .denied:
            return true
        case .notConnected, .unavailable, .requestingPermission, .failed:
            return false
        }
    }

    private func handlePrimaryAction() async {
        switch insightsStore.integrationState {
        case .denied:
            openHealthAccessSettings()
        case .notConnected, .failed:
            await insightsStore.connectAppleHealth()
        case .unavailable, .requestingPermission, .connected:
            break
        }
    }

    private func settingsRowLabel(_ title: String) -> some View {
        Text(title)
            .font(FormaTokens.Typography.body)
            .foregroundStyle(FormaTokens.Color.accent)
            .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .leading)
    }

    private func openHealthAccessSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

#Preview {
    NavigationStack {
        AppleHealthIntegrationView(
            insightsStore: TrainingInsightsStore(
                integration: StubTrainingIntegrationProvider(
                    refreshResult: .connected
                )
            )
        )
    }
    .preferredColorScheme(.dark)
}
