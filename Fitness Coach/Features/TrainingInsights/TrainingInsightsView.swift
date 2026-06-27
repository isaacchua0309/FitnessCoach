//
//  TrainingInsightsView.swift
//  Fitness Coach
//
//  Forma — Training Insights entry: Apple Health gate or connected dashboard.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TrainingInsightsView: View {

    @ObservedObject var insightsStore: TrainingInsightsStore
    @ObservedObject var insightsModel: TrainingInsightsModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    var body: some View {
        NavigationStack {
            screenContent
                .navigationTitle(TrainingIntegrationCopy.screenTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if insightsStore.integrationState.isConnected {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                Task { await insightsModel.refresh() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(FormaTokens.Color.textSecondary)
                            }
                            .accessibilityLabel("Refresh training insights")
                        }
                    }
                }
                .task {
                    await insightsStore.refresh()
                    if insightsStore.integrationState.isConnected {
                        await insightsModel.loadInsights()
                    }
                }
                .onChange(of: insightsStore.integrationState) { _, state in
                    guard state.isConnected else { return }
                    Task { await insightsModel.loadInsights() }
                }
                .onChange(of: refreshCenter.refreshToken) { _, _ in
                    Task {
                        await insightsStore.refresh()
                        if insightsStore.integrationState.isConnected {
                            await insightsModel.refresh()
                        }
                    }
                }
                .background(FormaTokens.Color.canvas)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        if insightsStore.integrationState.isConnected {
            TrainingInsightsConnectedView(
                model: insightsModel,
                insightsStore: insightsStore
            )
        } else {
            TrainingInsightsGateView(
                state: insightsStore.integrationState,
                onPrimaryAction: handlePrimaryAction
            )
        }
    }

    private func handlePrimaryAction() {
        switch insightsStore.integrationState {
        case .denied:
            HealthAppSettingsNavigator.openHealthPermissions()
        case .notConnected, .failed:
            Task { await insightsStore.connectAppleHealth() }
        case .unavailable, .requestingPermission, .connected:
            break
        }
    }

    private func openAppSettings() {
        HealthAppSettingsNavigator.openAppSettings()
    }
}

#Preview("Locked") {
    let container = try! AppContainer(inMemory: true)
    TrainingInsightsView(
        insightsStore: container.trainingInsightsStore,
        insightsModel: container.trainingInsightsModel
    )
    .environmentObject(container.refreshCenter)
}

#Preview("Connected stub") {
    TrainingInsightsConnectedScreenPreview()
        .preferredColorScheme(.dark)
}

@MainActor
private struct TrainingInsightsConnectedScreenPreview: View {
    @StateObject private var insightsStore: TrainingInsightsStore
    @StateObject private var insightsModel: TrainingInsightsModel

    init() {
        let healthService = HealthTrainingService()
        healthService.setStubConnected(true)
        let store = TrainingInsightsStore(integration: healthService)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let model = TrainingInsightsModel(
            workoutReader: MockHealthKitWorkoutReader(workouts: TrainingInsightsPreviewData.sampleWorkouts),
            dateProvider: FixedPreviewDateProvider(now: TrainingInsightsPreviewData.referenceNow),
            calendar: calendar
        )

        _insightsStore = StateObject(wrappedValue: store)
        _insightsModel = StateObject(wrappedValue: model)
    }

    var body: some View {
        TrainingInsightsView(
            insightsStore: insightsStore,
            insightsModel: insightsModel
        )
        .environmentObject(AppRefreshCenter())
        .task {
            await insightsStore.refresh()
            await insightsModel.refresh()
        }
    }
}

private struct FixedPreviewDateProvider: DateProviding {
    let now: Date

    func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
