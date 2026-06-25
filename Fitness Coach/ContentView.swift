//
//  ContentView.swift
//  Fitness Coach
//
//  Created by ByteDance on 25/6/26.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var todayModel: TodayModel

    init(container: AppContainer) {
        _todayModel = StateObject(wrappedValue: container.makeTodayModel())
    }

    var body: some View {
        TodayView(model: todayModel)
    }
}

#Preview {
    ContentView(container: try! AppContainer(inMemory: true))
}
