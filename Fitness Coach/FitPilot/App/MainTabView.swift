//
//  MainTabView.swift
//  Fitness Coach
//
//  FitPilot AI — Main tab shell shown after onboarding or when profile exists.
//

import SwiftUI

struct MainTabView: View {

    private let container: AppContainer

    @StateObject private var todayModel: TodayModel
    @StateObject private var coachModel: CoachModel
    @StateObject private var progressModel: ProgressModel
    @StateObject private var trainingModel: TrainingModel
    @StateObject private var profileModel: ProfileModel

    init(container: AppContainer) {
        self.container = container
        _todayModel = StateObject(wrappedValue: container.makeTodayModel())
        _coachModel = StateObject(wrappedValue: container.makeCoachModel())
        _progressModel = StateObject(wrappedValue: container.makeProgressModel())
        _trainingModel = StateObject(wrappedValue: container.makeTrainingModel())
        _profileModel = StateObject(wrappedValue: container.makeProfileModel())
    }

    var body: some View {
        TabView {
            TodayView(model: todayModel)
                .tabItem {
                    Label("Today", systemImage: "house")
                }

            CoachView(model: coachModel)
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right")
                }

            ProgressView(model: progressModel)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

            TrainingView(model: trainingModel)
                .tabItem {
                    Label("Training", systemImage: "dumbbell")
                }

            ProfileView(model: profileModel)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .environmentObject(container.refreshCenter)
    }
}

#Preview {
    MainTabView(container: try! AppContainer(inMemory: true))
}
