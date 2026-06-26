//
//  ContentView.swift
//  Fitness Coach
//
//  Created by ByteDance on 25/6/26.
//

import SwiftUI

struct ContentView: View {

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var body: some View {
        AuthGateView(container: container)
    }
}

#Preview {
    ContentView(container: try! AppContainer(inMemory: true))
}
