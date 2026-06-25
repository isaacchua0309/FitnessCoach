//
//  ContentView.swift
//  Fitness Coach
//
//  Created by ByteDance on 25/6/26.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var todayModel: TodayModel
    @StateObject private var coachModel: CoachModel
    @StateObject private var progressModel: ProgressModel
    @StateObject private var trainingModel: TrainingModel

    init(container: AppContainer) {
        _todayModel = StateObject(wrappedValue: container.makeTodayModel())
        _coachModel = StateObject(wrappedValue: container.makeCoachModel())
        _progressModel = StateObject(wrappedValue: container.makeProgressModel())
        _trainingModel = StateObject(wrappedValue: container.makeTrainingModel())
    }

    var body: some View {
        TabView {
            TodayView(model: todayModel)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
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
        }
    }
}

#Preview {
    ContentView(container: try! AppContainer(inMemory: true))
}
