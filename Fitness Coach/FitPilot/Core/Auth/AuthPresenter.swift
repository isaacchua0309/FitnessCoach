//
//  AuthPresenter.swift
//  Fitness Coach
//
//  FitPilot — UIKit presenter lookup for auth flows (kept out of SwiftUI views).
//

import UIKit

enum AuthPresenter {

    @MainActor
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        guard let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first,
            var top = window.rootViewController else {
            return nil
        }

        while let presented = top.presentedViewController {
            top = presented
        }

        if let navigation = top as? UINavigationController,
           let visible = navigation.visibleViewController {
            top = visible
            while let presented = top.presentedViewController {
                top = presented
            }
        }

        if let tabBar = top as? UITabBarController,
           let selected = tabBar.selectedViewController {
            top = selected
            while let presented = top.presentedViewController {
                top = presented
            }
        }

        return top
    }
}
