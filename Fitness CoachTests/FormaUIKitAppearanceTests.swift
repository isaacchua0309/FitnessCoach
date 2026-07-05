//
//  FormaUIKitAppearanceTests.swift
//  Fitness CoachTests
//
//  Forma — Guardrails for live UIKit appearance re-application on theme changes.
//

import XCTest
@testable import Fitness_Coach

final class FormaUIKitAppearanceTests: XCTestCase {

    func testFormaUIKitAppearanceAppliesTabBarNavigationAndList() throws {
        let source = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/DesignSystem/Theme/FormaUIKitAppearance.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("static func applyTabBarAppearance(from tokens: ThemeTokens)"),
            "FormaUIKitAppearance must expose tab bar appearance application."
        )
        XCTAssertTrue(
            source.contains("static func applyNavigationBarAppearance(from tokens: ThemeTokens)"),
            "FormaUIKitAppearance must expose navigation bar appearance application."
        )
        XCTAssertTrue(
            source.contains("static func applyListAppearance(from tokens: ThemeTokens)"),
            "FormaUIKitAppearance must expose list appearance application."
        )
        XCTAssertTrue(
            source.contains("UITabBarAppearance"),
            "Tab bar styling must use UITabBarAppearance."
        )
        XCTAssertTrue(
            source.contains("UINavigationBarAppearance"),
            "Navigation bar styling must use UINavigationBarAppearance."
        )
        XCTAssertTrue(
            source.contains(".onChange(of: themeManager.selectedTheme)"),
            "UIKit appearance bridge must re-apply when selectedTheme changes."
        )
        XCTAssertTrue(
            source.contains(".onChange(of: themeManager.themeRevision)"),
            "UIKit appearance bridge must re-apply when themeRevision changes."
        )
        XCTAssertTrue(
            source.contains("func formaUIKitAppearance()"),
            "UIKit appearance bridge must be available as a view modifier."
        )
    }

    func testRootAndMainTabReapplyUIKitAppearanceOnThemeChange() throws {
        let root = ThemeTestSupport.repositoryRoot()
        let rootModifierSource = try String(
            contentsOf: root.appendingPathComponent(
                "Fitness Coach/DesignSystem/Theme/FormaThemeScreenModifier.swift"
            ),
            encoding: .utf8
        )
        let mainTabSource = try String(
            contentsOf: root.appendingPathComponent("Fitness Coach/App/MainTabView.swift"),
            encoding: .utf8
        )
        let screenChromeSource = try String(
            contentsOf: root.appendingPathComponent(
                "Fitness Coach/DesignSystem/Components/FormaScreenChrome.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            rootModifierSource.contains(".formaUIKitAppearance()"),
            "App root must install UIKit appearance re-application."
        )
        XCTAssertTrue(
            mainTabSource.contains(".formaUIKitAppearance()"),
            "MainTabView must install UIKit appearance re-application."
        )
        XCTAssertTrue(
            mainTabSource.contains(".onChange(of: themeManager.selectedTheme)"),
            "MainTabView must re-apply native tab bar appearance when selectedTheme changes."
        )
        XCTAssertTrue(
            mainTabSource.contains("FormaUIKitAppearance.applyTabBarAppearance"),
            "MainTabView must explicitly rebuild UITabBarAppearance on theme changes."
        )
        XCTAssertTrue(
            mainTabSource.contains(".onAppear"),
            "MainTabView must apply native tab bar appearance on initial appear."
        )
        XCTAssertTrue(
            screenChromeSource.contains("FormaUIKitAppearance.applyListAppearance"),
            "Grouped lists must re-apply UITableView appearance on theme changes."
        )
        XCTAssertTrue(
            screenChromeSource.contains(".onChange(of: themeManager.selectedTheme)"),
            "Grouped lists must observe selectedTheme for UIKit list appearance."
        )
    }

    func testPremiumWeightRulerRepresentableRefreshesThemeInUpdateUIView() throws {
        let rulerSource = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/Features/Onboarding/Components/PremiumWeightRulerView.swift"
            ),
            encoding: .utf8
        )
        let scrollSource = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/Features/Onboarding/Components/PremiumWeightRulerScrollView.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            rulerSource.contains("@EnvironmentObject private var themeManager: ThemeManager"),
            "PremiumWeightRuler representable must observe ThemeManager for theme invalidation."
        )
        XCTAssertTrue(
            rulerSource.contains("host.ruler.applyTheme()"),
            "PremiumWeightRuler representable must re-apply theme in updateUIView."
        )
        XCTAssertTrue(
            scrollSource.contains("func applyTheme()"),
            "PremiumWeightRulerScrollView must expose applyTheme for live palette updates."
        )
    }
}
