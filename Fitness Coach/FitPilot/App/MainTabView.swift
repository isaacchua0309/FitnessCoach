//
//  MainTabView.swift
//  Fitness Coach
//
//  FitPilot AI — Main tab shell shown after onboarding or when profile exists.
//

import SwiftUI

private enum AppTab: String, Hashable {
    case today
    case coach
    case progress
    case profile

    /// Legacy tab id before Training was demoted (Stage 1). Maps to Journey.
    static let legacyTrainingTabID = "training"

    static func fromPersistedSelection(_ raw: String?) -> AppTab {
        guard let raw else { return .today }
        if raw == legacyTrainingTabID { return .progress }
        return AppTab(rawValue: raw) ?? .today
    }
}

struct MainTabView: View {

    private let container: AppContainer

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var todayModel: TodayModel
    @StateObject private var coachModel: CoachModel
    @StateObject private var progressModel: ProgressModel
    @StateObject private var profileModel: ProfileModel

    @State private var selectedTab: AppTab

    init(container: AppContainer) {
        self.container = container
        _todayModel = StateObject(wrappedValue: container.makeTodayModel())
        _coachModel = StateObject(wrappedValue: container.makeCoachModel())
        _progressModel = StateObject(wrappedValue: container.makeProgressModel())
        _profileModel = StateObject(wrappedValue: container.makeProfileModel())
        _selectedTab = State(initialValue: Self.resolveInitialTab())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(model: todayModel) { prefill in
                coachModel.prepareInput(prefill: prefill)
                selectedTab = .coach
            }
            .tabItem {
                Label("Today", systemImage: "house")
            }
            .tag(AppTab.today)

            CoachView(model: coachModel)
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right")
                }
            .tag(AppTab.coach)

            ProgressView(model: progressModel) { prefill in
                coachModel.prepareInput(prefill: prefill)
                selectedTab = .coach
            }
                .tabItem {
                    Label("Journey", systemImage: "chart.line.uptrend.xyaxis")
                }
            .tag(AppTab.progress)

            ProfileView(model: profileModel)
                .tabItem {
                    Label("Plan", systemImage: "target")
                }
            .tag(AppTab.profile)
        }
        .environmentObject(container.refreshCenter)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                container.refreshCenter.refreshIfDayChanged()
            }
        }
    }

    // MARK: - Tab selection

    private static let selectedTabStorageKey = "forma.mainTab.selectedTab"

    /// Training was removed from the tab bar; `TrainingView` remains for future push navigation.
    private static func resolveInitialTab() -> AppTab {
        let stored = UserDefaults.standard.string(forKey: selectedTabStorageKey)
        let tab = AppTab.fromPersistedSelection(stored)
        if stored == AppTab.legacyTrainingTabID {
            UserDefaults.standard.set(AppTab.progress.rawValue, forKey: selectedTabStorageKey)
        }
        return tab
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    MainTabView(container: container)
        .environmentObject(container.authManager)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
}
