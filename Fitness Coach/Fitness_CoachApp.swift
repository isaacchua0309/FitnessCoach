//
//  Fitness_CoachApp.swift
//  Fitness Coach
//
//  Created by ByteDance on 25/6/26.
//

import FirebaseCore
import SwiftUI
import UIKit

final class FormaAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }
}

@main
struct Fitness_CoachApp: App {

    @UIApplicationDelegateAdaptor(FormaAppDelegate.self) private var appDelegate

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
