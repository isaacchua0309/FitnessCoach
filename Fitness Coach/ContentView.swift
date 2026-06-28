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
    let container = try! AppContainer(inMemory: true)
    ContentView(container: container)
        .environmentObject(container.themeStore)
        .formaRootTheme(store: container.themeStore)
}
