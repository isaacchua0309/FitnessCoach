//
//  Fitness_CoachApp.swift
//  Fitness Coach
//
//  Created by ByteDance on 25/6/26.
//

import FirebaseCore
import SwiftUI

@main
struct Fitness_CoachApp: App {

    private let container: AppContainer

    init() {
        FirebaseApp.configure()

        do {
            container = try AppContainer()
        } catch {
            fatalError("Could not create FitPilot app container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .onOpenURL { url in
                    _ = container.authManager.handleIncomingURL(url)
                }
        }
    }
}
