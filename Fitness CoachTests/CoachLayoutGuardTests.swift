//
//  CoachLayoutGuardTests.swift
//  Fitness CoachTests
//
//  Guardrails for Coach chat layout after safeAreaInset bottom accessory migration.
//

import XCTest

final class CoachLayoutGuardTests: XCTestCase {

    func testCoachProductionSourcesAvoidObsoleteLayoutWorkarounds() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let violations = CoachLayoutGuard.scan(repositoryRoot: root)
        if violations.isEmpty { return }

        XCTFail(
            """
            Found \(violations.count) Coach layout guard violation(s).

            \(violations.joined(separator: "\n"))
            """
        )
    }

    func testGuardDetectsForbiddenKeyboardPaddingPattern() {
        let sample = """
        struct Demo: View {
            var body: some View {
                Text("Hi")
                    .padding(.bottom, keyboardHeight)
            }
        }
        """
        let violations = CoachLayoutGuard.scan(repositoryRoot: makeTemporaryCoachRepo(with: sample))
        XCTAssertTrue(violations.contains { $0.contains("keyboardHeight") })
    }

    func testGuardRequiresBottomAccessoryInset() {
        let root = makeTemporaryCoachRepo(with: "struct CoachConversationView: View { var body: some View { EmptyView() } }")
        let violations = CoachLayoutGuard.scan(repositoryRoot: root)
        XCTAssertTrue(
            violations.contains {
                $0.contains("CoachConversationView.swift")
                    && $0.contains("safeAreaInset(edge: .bottom")
            }
        )
    }

    func testProductionCoachSourcesExposePendingFoodAccessibilityIdentifiers() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let violations = CoachLayoutGuard.scan(repositoryRoot: root)
        if violations.isEmpty { return }

        XCTFail(
            """
            Coach layout guard failed for production sources.

            \(violations.joined(separator: "\n"))
            """
        )
    }

    private func makeTemporaryCoachRepo(with conversationSource: String) -> URL {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoachLayoutGuardTests-\(UUID().uuidString)", isDirectory: true)
        let coachDir = tempRoot
            .appendingPathComponent("Fitness Coach/Features/Coach/Components", isDirectory: true)
        try? FileManager.default.createDirectory(at: coachDir, withIntermediateDirectories: true)
        let conversationURL = coachDir.appendingPathComponent("CoachConversationView.swift")
        try? conversationSource.write(to: conversationURL, atomically: true, encoding: .utf8)
        let stackURL = coachDir.appendingPathComponent("CoachBottomAccessoryStack.swift")
        try? "struct CoachBottomAccessoryStack: View { var body: some View { CoachConfirmationBar() } }"
            .write(to: stackURL, atomically: true, encoding: .utf8)
        return tempRoot
    }
}
