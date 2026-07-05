//
//  FormaUIKitAppearance.swift
//  Fitness Coach
//
//  Forma — Re-applies UIKit appearance proxies when the active theme changes.
//

import SwiftUI
import UIKit

/// Maps semantic `ThemeTokens` into UIKit global and in-window appearance.
enum FormaUIKitAppearance {

    static func apply(from tokens: ThemeTokens) {
        applyTabBarAppearance(from: tokens)
        applyNavigationBarAppearance(from: tokens)
        applyListAppearance(from: tokens)
    }

    static func applyTabBarAppearance(from tokens: ThemeTokens) {
        let appearance = makeTabBarAppearance(from: tokens)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = uiColor(tokens.tabBarSelectedIcon)
        UITabBar.appearance().unselectedItemTintColor = uiColor(tokens.tabBarUnselectedIcon)

        forEachVisibleTabBar { tabBar in
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
            tabBar.tintColor = uiColor(tokens.tabBarSelectedIcon)
            tabBar.unselectedItemTintColor = uiColor(tokens.tabBarUnselectedIcon)
        }
    }

    static func applyNavigationBarAppearance(from tokens: ThemeTokens) {
        let standard = makeNavigationBarAppearance(from: tokens)

        UINavigationBar.appearance().standardAppearance = standard
        UINavigationBar.appearance().scrollEdgeAppearance = standard
        UINavigationBar.appearance().compactAppearance = standard
        UINavigationBar.appearance().tintColor = uiColor(tokens.accent)

        forEachVisibleNavigationBar { navigationBar in
            navigationBar.standardAppearance = standard
            navigationBar.scrollEdgeAppearance = standard
            navigationBar.compactAppearance = standard
            navigationBar.tintColor = uiColor(tokens.accent)
        }
    }

    static func applyListAppearance(from tokens: ThemeTokens) {
        UITableView.appearance().backgroundColor = uiColor(tokens.appBackground)
        UITableView.appearance(whenContainedInInstancesOf: [UIViewController.self]).backgroundColor =
            uiColor(tokens.appBackground)

        forEachVisibleTableView { tableView in
            tableView.backgroundColor = uiColor(tokens.appBackground)
        }
    }

    // MARK: - Appearance builders

    private static func makeTabBarAppearance(from tokens: ThemeTokens) -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = uiColor(tokens.tabBarBackground)
        appearance.shadowColor = uiColor(tokens.inputBorder.opacity(0.35))

        configureTabBarItemAppearance(appearance.stackedLayoutAppearance, tokens: tokens)
        configureTabBarItemAppearance(appearance.inlineLayoutAppearance, tokens: tokens)
        configureTabBarItemAppearance(appearance.compactInlineLayoutAppearance, tokens: tokens)

        return appearance
    }

    private static func configureTabBarItemAppearance(
        _ itemAppearance: UITabBarItemAppearance,
        tokens: ThemeTokens
    ) {
        let normal = itemAppearance.normal
        normal.iconColor = uiColor(tokens.tabBarUnselectedIcon)
        normal.titleTextAttributes = [.foregroundColor: uiColor(tokens.tabBarUnselectedIcon)]

        let selected = itemAppearance.selected
        selected.iconColor = uiColor(tokens.tabBarSelectedIcon)
        selected.titleTextAttributes = [.foregroundColor: uiColor(tokens.tabBarSelectedIcon)]
    }

    private static func makeNavigationBarAppearance(from tokens: ThemeTokens) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = uiColor(tokens.appBackground)
        appearance.shadowColor = uiColor(tokens.inputBorder.opacity(0.35))
        appearance.titleTextAttributes = [.foregroundColor: uiColor(tokens.primaryText)]
        appearance.largeTitleTextAttributes = [.foregroundColor: uiColor(tokens.primaryText)]
        return appearance
    }

    // MARK: - Visible hierarchy traversal

    private static func forEachVisibleTabBar(_ body: (UITabBar) -> Void) {
        forEachRootViewController { root in
            visit(viewController: root) { viewController in
                if let tabBarController = viewController as? UITabBarController {
                    body(tabBarController.tabBar)
                }
                if let tabBar = viewController.tabBarController?.tabBar {
                    body(tabBar)
                }
            }
        }
    }

    private static func forEachVisibleNavigationBar(_ body: (UINavigationBar) -> Void) {
        forEachRootViewController { root in
            visit(viewController: root) { viewController in
                if let navigationBar = viewController.navigationController?.navigationBar {
                    body(navigationBar)
                }
            }
        }
    }

    private static func forEachVisibleTableView(_ body: (UITableView) -> Void) {
        forEachRootViewController { root in
            visit(view: root.view) { view in
                if let tableView = view as? UITableView {
                    body(tableView)
                }
            }
        }
    }

    private static func forEachRootViewController(_ body: (UIViewController) -> Void) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.isKeyWindow || window.isHidden == false {
                if let root = window.rootViewController {
                    body(root)
                }
            }
        }
    }

    private static func visit(
        viewController: UIViewController,
        _ body: (UIViewController) -> Void
    ) {
        body(viewController)
        for child in viewController.children {
            visit(viewController: child, body)
        }
        if let presented = viewController.presentedViewController {
            visit(viewController: presented, body)
        }
    }

    private static func visit(view: UIView, _ body: (UIView) -> Void) {
        body(view)
        for subview in view.subviews {
            visit(view: subview, body)
        }
    }

    private static func uiColor(_ color: Color) -> UIColor {
        UIColor(color)
    }
}

// MARK: - SwiftUI bridge

private struct FormaUIKitAppearanceModifier: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .onAppear {
                applyAppearance()
            }
            .onChange(of: themeManager.selectedTheme) { _, _ in
                applyAppearance()
            }
            .onChange(of: themeManager.themeRevision) { _, _ in
                applyAppearance()
            }
            .onChange(of: systemColorScheme) { _, _ in
                applyAppearance()
            }
    }

    private func applyAppearance() {
        let _ = theme.accent
        FormaUIKitAppearance.apply(from: themeManager.tokens(systemColorScheme: systemColorScheme))
    }
}

extension View {
    /// Re-applies UIKit tab bar, navigation bar, and list appearance when theme changes.
    func formaUIKitAppearance() -> some View {
        modifier(FormaUIKitAppearanceModifier())
    }
}
