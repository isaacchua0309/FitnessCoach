//
//  PlanLayoutGuard.swift
//  Fitness CoachTests
//
//  Prevents regression of Plan tab header actions after main-tab layout migration.
//

import Foundation

enum PlanLayoutGuard {

    static let planSourceRoot = "Fitness Coach/Features/Plan"

    static let forbiddenPatterns: [(pattern: String, reason: String)] = [
        (
            "planHeaderTrailingActions",
            "Plan header actions must use PageActionPill in MainTabPageScaffold, not a legacy HStack helper."
        ),
        (
            "title: FormaProductCopy.PlanMissionControl.adjustPlan",
            "Plan header pill must use the compact adjustPlanPill copy, not the full Adjust Plan label."
        ),
    ]

    static let requiredPatterns: [(fileSuffix: String, pattern: String, reason: String)] = [
        (
            "PlanView.swift",
            "PageActionPill",
            "Plan loaded state must expose a compact Adjust pill in the shared page header."
        ),
        (
            "PlanView.swift",
            "FormaProductCopy.PlanMissionControl.adjustPlanPill",
            "Plan header Adjust pill must use the compact adjustPlanPill copy token."
        ),
        (
            "PlanView.swift",
            "model.showEditPlan",
            "Plan header Adjust pill must open the existing Adjust Plan wizard."
        ),
        (
            "PlanView.swift",
            "model.showSettings()",
            "Plan must still expose app settings from the dashboard."
        ),
        (
            "PlanView.swift",
            "onOpenSettings:",
            "Plan dashboard content must receive a settings handler."
        ),
        (
            "PlanDashboardContent.swift",
            "PlanSettingsAccessRow",
            "Plan settings access must live in a secondary dashboard row, not the header."
        ),
        (
            "PlanSettingsAccessRow.swift",
            "plan-settings-access",
            "Plan settings row must expose a stable accessibility identifier."
        ),
    ]

    static func scan(repositoryRoot: URL) -> [String] {
        let planURL = repositoryRoot.appendingPathComponent(planSourceRoot)
        guard let enumerator = FileManager.default.enumerator(
            at: planURL,
            includingPropertiesForKeys: nil
        ) else {
            return ["Could not enumerate \(planSourceRoot)"]
        }

        var violations: [String] = []
        var fileContents: [String: String] = [:]

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let relativePath = fileURL.path
                .replacingOccurrences(of: repositoryRoot.path + "/", with: "")
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let productionSource = stripPreviewBlocks(from: source)
            fileContents[relativePath] = productionSource

            if relativePath.hasSuffix("PlanView.swift") {
                for rule in forbiddenPatterns where productionSource.contains(rule.pattern) {
                    violations.append("\(relativePath): \(rule.reason) (found `\(rule.pattern)`).")
                }

                if productionSource.contains("gearshape") {
                    violations.append(
                        "\(relativePath): Plan header must not show a dominant gear icon; use PlanSettingsAccessRow."
                    )
                }
            }
        }

        for requirement in requiredPatterns {
            guard let source = fileContents.first(where: { $0.key.hasSuffix(requirement.fileSuffix) })?.value else {
                violations.append("Missing \(planSourceRoot)/**/\(requirement.fileSuffix)")
                continue
            }
            guard source.contains(requirement.pattern) else {
                violations.append(
                    "\(planSourceRoot)/**/\(requirement.fileSuffix): \(requirement.reason)"
                )
                continue
            }
        }

        return violations
    }

    private static func stripPreviewBlocks(from source: String) -> String {
        guard let previewStart = source.range(of: "#Preview") else { return source }
        return String(source[..<previewStart.lowerBound])
    }
}
