//
//  CoachLayoutGuard.swift
//  Fitness CoachTests
//
//  Prevents regression to brittle Coach chat layout workarounds.
//

import Foundation

enum CoachLayoutGuard {

    static let coachSourceRoot = "Fitness Coach/Features/Coach"

    static let forbiddenPatterns: [(pattern: String, reason: String)] = [
        ("bottomChromeInset", "Use safeAreaInset bottom accessory instead of manual tab-bar lift padding."),
        ("keyboardHeight", "Coach must not use manual keyboard-height padding; rely on safeAreaInset."),
        ("OnboardingKeyboardMonitor", "Coach must not use onboarding keyboard observers."),
        ("UIResponder.keyboard", "Coach must not use UIKit keyboard notifications."),
        ("ignoresSafeArea(.keyboard", "Coach must respect keyboard safe area."),
        ("overlay(alignment: .bottom)", "Pending card and composer must live in safeAreaInset, not bottom overlays."),
        (".formaMainTabScrollInsets()", "Coach uses its own bottom accessory inset; do not stack tab-bar scroll insets."),
    ]

    static let requiredPatterns: [(fileSuffix: String, pattern: String, reason: String)] = [
        (
            "CoachConversationView.swift",
            "CoachPageHeader",
            "Coach transcript must show the shared in-scroll page header."
        ),
        (
            "CoachBottomAccessoryStack.swift",
            "CoachConfirmationBar",
            "Pending confirmation and composer must share one bottom accessory stack."
        ),
        (
            "CoachConversationView.swift",
            "coach.chat.scroll",
            "Coach transcript scroll must expose a stable accessibility identifier."
        ),
        (
            "CoachComposer.swift",
            "coach.input.textfield",
            "Coach composer must expose a stable input accessibility identifier."
        ),
        (
            "CoachConfirmationBar.swift",
            "coach.pendingFoodCard",
            "Pending food card must expose a stable accessibility identifier."
        ),
        (
            "CoachConfirmationBar.swift",
            "coach.pendingFoodCard.logButton",
            "Pending food card Log action must remain discoverable to UI tests."
        ),
        (
            "CoachConfirmationBar.swift",
            "coach.pendingFoodCard.discardButton",
            "Pending food card Discard action must remain discoverable to UI tests."
        ),
    ]

    static func scan(repositoryRoot: URL) -> [String] {
        let coachURL = repositoryRoot.appendingPathComponent(coachSourceRoot)
        guard let enumerator = FileManager.default.enumerator(
            at: coachURL,
            includingPropertiesForKeys: nil
        ) else {
            return ["Could not enumerate \(coachSourceRoot)"]
        }

        var violations: [String] = []
        var fileContents: [String: String] = [:]

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let relativePath = fileURL.path
                .replacingOccurrences(of: repositoryRoot.path + "/", with: "")
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let productionSource = stripPreviewBlocks(from: source)
            fileContents[relativePath] = productionSource

            for rule in forbiddenPatterns where productionSource.contains(rule.pattern) {
                violations.append("\(relativePath): \(rule.reason) (found `\(rule.pattern)`).")
            }
        }

        for requirement in requiredPatterns {
            guard let source = fileContents.first(where: { $0.key.hasSuffix(requirement.fileSuffix) })?.value else {
                violations.append("Missing \(coachSourceRoot)/**/\(requirement.fileSuffix)")
                continue
            }
            guard source.contains(requirement.pattern) else {
                violations.append(
                    "\(coachSourceRoot)/**/\(requirement.fileSuffix): \(requirement.reason)"
                )
            }
        }

        return violations
    }

    private static func stripPreviewBlocks(from source: String) -> String {
        guard let previewStart = source.range(of: "#Preview") else { return source }
        return String(source[..<previewStart.lowerBound])
    }
}
