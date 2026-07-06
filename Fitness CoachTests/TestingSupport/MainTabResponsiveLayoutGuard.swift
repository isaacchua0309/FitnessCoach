//
//  MainTabResponsiveLayoutGuard.swift
//  Fitness CoachTests
//
//  Guardrails for small-screen and Dynamic Type resilience on main-tab layout.
//

import Foundation

enum MainTabResponsiveLayoutGuard {

    static let responsiveSources = [
        "Fitness Coach/DesignSystem/Layout/MainTabResponsiveLayout.swift",
        "Fitness Coach/DesignSystem/Components/PageHeader.swift",
        "Fitness Coach/DesignSystem/Components/PageActionPill.swift",
        "Fitness Coach/DesignSystem/Components/MainTabHeroText.swift",
        "Fitness Coach/DesignSystem/Components/FormaPlanCard.swift",
        "Fitness Coach/Features/Today/Components/TodayWaterQuickLogSection.swift",
        "Fitness Coach/Features/Coach/Components/CoachStarterChips.swift",
        "Fitness Coach/Features/Coach/Components/CoachLaunchChips.swift"
    ]

    static func scan(repositoryRoot: URL) -> [String] {
        var violations: [String] = []

        for relativePath in responsiveSources {
            let fileURL = repositoryRoot.appendingPathComponent(relativePath)
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
                violations.append("Missing responsive layout source: \(relativePath)")
                continue
            }
            let productionSource = stripPreviewBlocks(from: source)
            scanFile(relativePath: relativePath, productionSource: productionSource, violations: &violations)
        }

        return violations
    }

    private static func scanFile(
        relativePath: String,
        productionSource: String,
        violations: inout [String]
    ) {
        switch relativePath {
        case "Fitness Coach/DesignSystem/Components/PageHeader.swift":
            if productionSource.contains("minimumScaleFactor") {
                violations.append("\(relativePath): page title should wrap instead of shrinking with minimumScaleFactor.")
            }
            if !productionSource.contains(".top, spacing:") {
                violations.append("\(relativePath): title/action row must top-align to avoid pill overlap.")
            }
            if !productionSource.contains("fixedSize(horizontal: true") {
                violations.append("\(relativePath): trailing action pill must reserve intrinsic width.")
            }

        case "Fitness Coach/DesignSystem/Components/MainTabHeroText.swift":
            if productionSource.contains("minimumScaleFactor(0.55)")
                || productionSource.contains("minimumScaleFactor(0.65)") {
                violations.append("\(relativePath): hero text minimumScaleFactor is too aggressive for readability.")
            }
            if !productionSource.contains("MainTabResponsiveLayout.heroMinimumScaleFactor") {
                violations.append("\(relativePath): hero text must use shared responsive scale floors.")
            }

        case "Fitness Coach/Features/Today/Components/TodayWaterQuickLogSection.swift":
            if productionSource.contains("HStack(spacing: FormaTokens.Spacing.sm)") {
                violations.append("\(relativePath): water quick-add buttons must use a flexible grid on small screens.")
            }
            if !productionSource.contains("LazyVGrid") {
                violations.append("\(relativePath): water quick-add buttons must use LazyVGrid.")
            }

        case "Fitness Coach/Features/Coach/Components/CoachStarterChips.swift",
             "Fitness Coach/Features/Coach/Components/CoachLaunchChips.swift":
            if !productionSource.contains("LazyVGrid") {
                violations.append("\(relativePath): Coach quick actions must use a flexible grid layout.")
            }

        default:
            break
        }
    }

    private static func stripPreviewBlocks(from source: String) -> String {
        guard let previewStart = source.range(of: "#Preview") else { return source }
        return String(source[..<previewStart.lowerBound])
    }
}
