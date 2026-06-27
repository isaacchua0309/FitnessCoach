//
//  HealthAppSettingsNavigator.swift
//  Fitness Coach
//
//  Forma — Opens Health app / settings for workout permission management.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum HealthAppSettingsNavigator {

    /// Workout read access is managed in the Health app, not Settings → Forma.
    static func openHealthPermissions() {
        #if canImport(UIKit)
        if let healthURL = URL(string: "x-apple-health://") {
            UIApplication.shared.open(healthURL, options: [:]) { opened in
                guard !opened else { return }
                openAppSettings()
            }
            return
        }
        openAppSettings()
        #endif
    }

    static func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
