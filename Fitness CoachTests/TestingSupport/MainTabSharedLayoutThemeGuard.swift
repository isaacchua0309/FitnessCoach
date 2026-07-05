//
//  MainTabSharedLayoutThemeGuard.swift
//  Fitness CoachTests
//
//  Guardrails ensuring shared main-tab layout components observe live theme state.
//

import Foundation

enum MainTabSharedLayoutThemeGuard {

    static let sharedLayoutSources = [
        "Fitness Coach/DesignSystem/Layout/MainTabPageScaffold.swift",
        "Fitness Coach/DesignSystem/Components/PageHeader.swift",
        "Fitness Coach/DesignSystem/Components/SectionLabel.swift",
        "Fitness Coach/DesignSystem/Components/MainTabCard.swift",
        "Fitness Coach/DesignSystem/Components/FormaCardChrome.swift",
        "Fitness Coach/DesignSystem/Components/PageActionPill.swift",
        "Fitness Coach/DesignSystem/Components/MainTabHeroText.swift",
        "Fitness Coach/DesignSystem/Components/FormaInlineEmptyState.swift"
    ]

    static let forbiddenProductionPatterns: [(pattern: String, reason: String)] = [
        (
            "FormaTokens.Color.textPrimary",
            "Shared layout components must use @Environment(\\.theme) semantic tokens, not static FormaTokens.Color text bridges."
        ),
        (
            "FormaTokens.Color.textSecondary",
            "Shared layout components must use @Environment(\\.theme) semantic tokens, not static FormaTokens.Color text bridges."
        ),
        (
            "FormaTokens.Color.textTertiary",
            "Shared layout components must use @Environment(\\.theme) semantic tokens, not static FormaTokens.Color text bridges."
        ),
        (
            "FormaTokens.Color.accent",
            "Shared layout components must use @Environment(\\.theme) semantic accent tokens."
        ),
        (
            "CoachDesignTokens.Color.",
            "Shared main-tab layout components must not depend on Coach-only static color bridges."
        )
    ]

    static func scan(repositoryRoot: URL) -> [String] {
        var violations: [String] = []

        for relativePath in sharedLayoutSources {
            let fileURL = repositoryRoot.appendingPathComponent(relativePath)
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
                violations.append("Missing shared layout source: \(relativePath)")
                continue
            }

            let productionSource = stripPreviewBlocks(from: source)

            let observesThemeManager = productionSource.contains("@EnvironmentObject private var themeManager: ThemeManager")
                || productionSource.contains("@EnvironmentObject private var themeStore: ThemeStore")
            let observesThemeRevision = productionSource.contains("themeManager.themeRevision")
                || productionSource.contains("themeStore.themeRevision")
            let observesThemeEnvironment = productionSource.contains("@Environment(\\.theme)")
            let usesReactiveModifier = productionSource.contains("formaThemeReactive()")

            if !observesThemeEnvironment {
                violations.append("\(relativePath): must read @Environment(\\.theme) semantic tokens.")
            }

            if !(observesThemeRevision || usesReactiveModifier) {
                violations.append("\(relativePath): must observe themeRevision or apply formaThemeReactive().")
            }

            if !observesThemeManager && !productionSource.contains("@EnvironmentObject private var themeStore: ThemeStore") {
                violations.append("\(relativePath): must observe ThemeManager/ThemeStore via @EnvironmentObject.")
            }

            for rule in forbiddenProductionPatterns where productionSource.contains(rule.pattern) {
                violations.append("\(relativePath): \(rule.reason) (found `\(rule.pattern)`).")
            }
        }

        return violations
    }

    private static func stripPreviewBlocks(from source: String) -> String {
        guard let previewStart = source.range(of: "#Preview") else { return source }
        return String(source[..<previewStart.lowerBound])
    }
}
