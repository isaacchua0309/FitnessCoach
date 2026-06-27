//
//  TrainingView.swift
//  Fitness Coach
//
//  Forma — Compatibility wrapper for Training Insights.
//
//  Training was removed from the main tab bar. Use `TrainingInsightsView` for push navigation.
//

import SwiftUI

struct TrainingView: View {

    @ObservedObject var insightsStore: TrainingInsightsStore
    @ObservedObject var insightsModel: TrainingInsightsModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    var body: some View {
        TrainingInsightsView(insightsStore: insightsStore, insightsModel: insightsModel)
            .environmentObject(refreshCenter)
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    TrainingView(
        insightsStore: container.trainingInsightsStore,
        insightsModel: container.trainingInsightsModel
    )
    .environmentObject(container.refreshCenter)
}
