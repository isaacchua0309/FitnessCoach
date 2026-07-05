//
//  LiveThemeSwitchingTests.swift
//  Fitness CoachTests
//
//  Forma — Unit and guardrail tests for live palette switching.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class LiveThemeSwitchingTests: XCTestCase {

  private let accentSurfacePaths = [
    "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayRecoveryCard.swift",
    "Fitness Coach/Features/Today/Components/TodayNutritionProgressCard.swift",
    "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayNextBestActionCard.swift",
    "Fitness Coach/App/MainTabView.swift",
    "Fitness Coach/Features/Coach/Components/CoachComposer.swift"
  ]

  override func tearDown() async throws {
    await MainActor.run {
      ThemeTestSupport.resetThemeAccessToProductDefault()
    }
    try await super.tearDown()
  }

  // MARK: - ThemeManager unit tests

  func testSetThemeUpdatesSelectedThemeImmediately() async {
    await MainActor.run {
      let store = ThemeStore(
        userDefaults: ThemeTestSupport.makeIsolatedDefaults(
          suiteNamePrefix: "LiveThemeSwitchingTests.immediate"
        )
      )

      XCTAssertEqual(store.selectedTheme, .oceanBlue)

      store.setTheme(.blossomPink)

      XCTAssertEqual(store.selectedTheme, .blossomPink)
      XCTAssertEqual(store.palette, .blossomPink)
    }
  }

  func testSetThemePersistsSelectedTheme() async {
    await MainActor.run {
      let defaults = ThemeTestSupport.makeIsolatedDefaults(
        suiteNamePrefix: "LiveThemeSwitchingTests.persist"
      )
      let store = ThemeStore(userDefaults: defaults)

      store.setTheme(.emeraldGreen)

      XCTAssertEqual(
        defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
        AppThemePalette.emeraldGreen.persistenceRawValue
      )
    }
  }

  func testNewThemeManagerLoadsPersistedSelectedThemeOnInit() async {
    await MainActor.run {
      let defaults = ThemeTestSupport.makeIsolatedDefaults(
        suiteNamePrefix: "LiveThemeSwitchingTests.reload"
      )
      defaults.set(
        AppThemePalette.sunsetOrange.persistenceRawValue,
        forKey: AppThemePreferences.PersistenceKey.palette
      )

      let store = ThemeStore(userDefaults: defaults)

      XCTAssertEqual(store.selectedTheme, .sunsetOrange)
    }
  }

  func testThemeTokensChangeWhenSelectedThemeChanges() async {
    await MainActor.run {
      let store = ThemeStore(
        userDefaults: ThemeTestSupport.makeIsolatedDefaults(
          suiteNamePrefix: "LiveThemeSwitchingTests.tokens"
        )
      )

      store.setTheme(.oceanBlue)
      let blueTokens = store.tokens(systemColorScheme: .dark)

      store.setTheme(.blossomPink)
      let pinkTokens = store.tokens(systemColorScheme: .dark)

      XCTAssertGreaterThan(
        ThemeTestSupport.colorDistance(blueTokens.accent, pinkTokens.accent),
        0.08,
        "Accent token must change when selectedTheme changes."
      )
      XCTAssertGreaterThan(
        ThemeTestSupport.colorDistance(blueTokens.accentBorder, pinkTokens.accentBorder),
        0.05,
        "Accent border token must change when selectedTheme changes."
      )
      XCTAssertGreaterThan(
        ThemeTestSupport.colorDistance(blueTokens.tabBarSelectedIcon, pinkTokens.tabBarSelectedIcon),
        0.08,
        "Tab bar selected icon token must change when selectedTheme changes."
      )
    }
  }

  // MARK: - Blue vs pink accent differentiation

  func testOceanBlueAndBlossomPinkResolvedAccentsDiffer() async {
    await MainActor.run {
      let blue = ThemeTestSupport.makeResolved(palette: .oceanBlue, systemColorScheme: .dark)
      let pink = ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)

      XCTAssertGreaterThan(
        ThemeTestSupport.colorDistance(blue.themePalette.primary, pink.themePalette.primary),
        0.08
      )

      let blueTokens = ThemeTokensProvider.tokens(from: blue)
      let pinkTokens = ThemeTokensProvider.tokens(from: pink)

      XCTAssertGreaterThan(ThemeTestSupport.colorDistance(blueTokens.accentLine, pinkTokens.accentLine), 0.05)
      XCTAssertGreaterThan(
        ThemeTestSupport.colorDistance(blueTokens.accentSoftBackground, pinkTokens.accentSoftBackground),
        0.03
      )
    }
  }

  // MARK: - Reusable UI source guardrails

  func testAccentSurfacesUseSemanticThemeTokens() throws {
    let root = ThemeTestSupport.repositoryRoot()

    for relativePath in accentSurfacePaths {
      let source = try String(
        contentsOf: root.appendingPathComponent(relativePath),
        encoding: .utf8
      )
      let productionSource = source.components(separatedBy: "#Preview").first ?? source

      XCTAssertTrue(
        productionSource.contains("@Environment(\\.theme)")
          || productionSource.contains("themeManager.themeRevision")
          || productionSource.contains("FormaCardChrome"),
        "\(relativePath) must read live semantic theme tokens for accent chrome."
      )
      XCTAssertFalse(
        productionSource.contains("Color.blue")
          || productionSource.contains("Color.pink")
          || productionSource.contains("Color(\"Blue\")")
          || productionSource.contains("Color(\"Pink\")")
          || productionSource.contains("formaBlue")
          || productionSource.contains("formaPink"),
        "\(relativePath) must not hardcode blue/pink palette literals."
      )
    }
  }

  func testMainTabBarUsesSemanticTabBarSelectedIcon() throws {
    let source = try String(
      contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
        "Fitness Coach/App/MainTabView.swift"
      ),
      encoding: .utf8
    )

    XCTAssertTrue(source.contains("theme.tabBarSelectedIcon"))
    XCTAssertTrue(source.contains("FormaUIKitAppearance.applyTabBarAppearance"))
  }

  func testCoachComposerUsesSemanticAccentTokens() throws {
    let source = try String(
      contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
        "Fitness Coach/Features/Coach/Components/CoachComposer.swift"
      ),
      encoding: .utf8
    )

    XCTAssertTrue(source.contains("theme.accent"))
    XCTAssertTrue(source.contains("@EnvironmentObject private var themeManager: ThemeManager"))
  }

  func testNoPaletteLiteralsInReusableUIComponents() {
    let violations = ThemePaletteLiteralGuard.scan(repositoryRoot: ThemeTestSupport.repositoryRoot())
    if violations.isEmpty { return }

    let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
    XCTFail(
      """
      Found \(violations.count) blue/pink palette literal(s) in reusable UI outside theme definitions.

      \(report)
      """
    )
  }

  // MARK: - Preview / debug harness guardrails

  func testTodayBlueAndPinkPreviewsExist() throws {
    let source = try String(
      contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
        "Fitness Coach/DesignSystem/Preview/MainTabThemePreviewScreens.swift"
      ),
      encoding: .utf8
    )

    XCTAssertTrue(source.contains("#Preview(\"Today — Ocean Blue\")"))
    XCTAssertTrue(source.contains("#Preview(\"Today — Blossom Pink\")"))
    XCTAssertTrue(source.contains("MainTabThemePreviewScreens.today(palette: .blossomPink)"))
    XCTAssertTrue(source.contains("#Preview(\"Recovery card — Ocean Blue\")"))
    XCTAssertTrue(source.contains("#Preview(\"Recovery card — Blossom Pink\")"))
    XCTAssertTrue(source.contains("#Preview(\"Nutrition card — Ocean Blue\")"))
    XCTAssertTrue(source.contains("#Preview(\"Nutrition card — Blossom Pink\")"))
    XCTAssertTrue(source.contains("#Preview(\"Next action card — Ocean Blue\")"))
    XCTAssertTrue(source.contains("#Preview(\"Next action card — Blossom Pink\")"))
    XCTAssertTrue(source.contains("#Preview(\"Main tab bar — Ocean Blue\")"))
    XCTAssertTrue(source.contains("#Preview(\"Main tab bar — Blossom Pink\")"))
    XCTAssertTrue(source.contains("#Preview(\"Coach input — Ocean Blue\")"))
    XCTAssertTrue(source.contains("#Preview(\"Coach input — Blossom Pink\")"))
  }

  func testLiveThemeDebugHarnessSupportsMountedToggle() throws {
    let harnessSource = try String(
      contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
        "Fitness Coach/DesignSystem/Preview/LiveThemeDebugHarness.swift"
      ),
      encoding: .utf8
    )
    let todaySource = try String(
      contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
        "Fitness Coach/Features/Today/TodayView.swift"
      ),
      encoding: .utf8
    )

    XCTAssertTrue(harnessSource.contains("themeManager.setTheme"))
    XCTAssertTrue(harnessSource.contains("formaRootTheme()"))
    XCTAssertTrue(harnessSource.contains("LiveThemeDebugHarness"))
        XCTAssertTrue(
            todaySource.contains("LiveThemeDebugHarness"),
            "Today must expose a debug preview for toggling theme while mounted."
        )
  }

  func testRecoveryNutritionAndNextActionCardsObserveLiveTheme() throws {
    let root = ThemeTestSupport.repositoryRoot()
    let cardPaths = [
      "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayRecoveryCard.swift",
      "Fitness Coach/Features/Today/Components/TodayNutritionProgressCard.swift",
      "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayNextBestActionCard.swift"
    ]

    for relativePath in cardPaths {
      let source = try String(
        contentsOf: root.appendingPathComponent(relativePath),
        encoding: .utf8
      )
      XCTAssertTrue(
        source.contains("todayLiveTheme()") || source.contains("themeManager.themeRevision"),
        "\(relativePath) must observe live theme changes."
      )
      XCTAssertTrue(
        source.contains("FormaCardChrome") || source.contains("TodayActionCard"),
        "\(relativePath) must use shared accent card chrome."
      )
    }
  }
}
