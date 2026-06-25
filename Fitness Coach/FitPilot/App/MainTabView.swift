//
//  MainTabView.swift
//  Fitness Coach
//
//  FitPilot AI — Main tab shell shown after onboarding or when profile exists.
//

import SwiftUI

private enum AppTab: Hashable {
    case today
    case coach
    case progress
    case training
    case profile
}

struct MainTabView: View {

    private let container: AppContainer

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var todayModel: TodayModel
    @StateObject private var coachModel: CoachModel
    @StateObject private var progressModel: ProgressModel
    @StateObject private var trainingModel: TrainingModel
    @StateObject private var profileModel: ProfileModel

    @State private var selectedTab: AppTab = .today

    init(container: AppContainer) {
        self.container = container
        _todayModel = StateObject(wrappedValue: container.makeTodayModel())
        _coachModel = StateObject(wrappedValue: container.makeCoachModel())
        _progressModel = StateObject(wrappedValue: container.makeProgressModel())
        _trainingModel = StateObject(wrappedValue: container.makeTrainingModel())
        _profileModel = StateObject(wrappedValue: container.makeProfileModel())
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

            ProgressView(model: progressModel)
                .tabItem {
                    Label("Journey", systemImage: "chart.line.uptrend.xyaxis")
                }
            .tag(AppTab.progress)

            TrainingView(model: trainingModel)
                .tabItem {
                    Label("Training", systemImage: "dumbbell")
                }
            .tag(AppTab.training)

            ProfileView(model: profileModel)
                .tabItem {
                    Label("Plan", systemImage: "target")
                }
            .tag(AppTab.profile)
        }
        .environmentObject(container.refreshCenter)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                container.refreshCenter.refreshIfDayChanged()
            }
        }
    }
}

#Preview {
    MainTabView(container: try! AppContainer(inMemory: true))
}
