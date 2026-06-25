//
//  Fitness_CoachApp.swift
//  Fitness Coach
//
//  Created by ByteDance on 25/6/26.
//

import SwiftUI

@main
struct Fitness_CoachApp: App {

    private let container: AppContainer

    init() {
        do {
            container = try AppContainer()
        } catch {
            fatalError("Could not create FitPilot app container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
