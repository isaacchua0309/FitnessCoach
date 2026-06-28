//
//  PreferredColorSchemeGuardTests.swift
//  Fitness CoachTests
//
//  Forma — Fails when production code hard-forces appearance outside root theme wiring.
//

import XCTest
@testable import Fitness_Coach

final class PreferredColorSchemeGuardTests: XCTestCase {

    func testProductionCodeDoesNotForceDarkPreferredColorScheme() {
        let violations = ForcedDarkAppearanceGuard.scan(
            repositoryRoot: ThemeTestSupport.repositoryRoot()
        )
        if violations.isEmpty { return }

        let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
        XCTFail(
            """
            Found \(violations.count) forced dark appearance override(s) outside approved root theme wiring.

            \(report)

            Appearance must be resolved once at the app root via `FormaRootThemeModifier` and `ThemeStore`.
            Use `.formaThemePreview()` inside `#Preview` blocks when a fixed theme is needed.
            Approved production files: \(ForcedDarkAppearanceGuard.approvedRelativePaths.sorted().joined(separator: ", "))
            """
        )
    }

    func testGuardDetectsForcedDarkInProductionSample() {
        let tempRoot = makeTemporaryRepo(
            with: """
            Text("Hi")
                .preferredColorScheme(.dark)
            """
        )
        let violations = ForcedDarkAppearanceGuard.scan(repositoryRoot: tempRoot)
        XCTAssertEqual(violations.count, 1)
    }

    func testGuardIgnoresPreviewBlocks() {
        let tempRoot = makeTemporaryRepo(
            with: """
            struct Demo: View {
                var body: some View { Text("Hi") }
            }

            #Preview {
                Text("Preview")
                    .preferredColorScheme(.dark)
            }
            """
        )
        let violations = ForcedDarkAppearanceGuard.scan(repositoryRoot: tempRoot)
        XCTAssertTrue(violations.isEmpty)
    }

    func testGuardIgnoresRootThemeModifierFile() throws {
        let tempRoot = makeTemporaryRepo(with: "Text(\"Hi\")")
        let modifierURL = tempRoot.appendingPathComponent(
            "Fitness Coach/DesignSystem/Theme/FormaThemeScreenModifier.swift"
        )
        try FileManager.default.createDirectory(
            at: modifierURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        import SwiftUI
        struct FormaRootThemeModifier: ViewModifier {
            func body(content: Content) -> some View {
                content.preferredColorScheme(.dark)
            }
        }
        """.write(to: modifierURL, atomically: true, encoding: .utf8)

        let violations = ForcedDarkAppearanceGuard.scan(repositoryRoot: tempRoot)
        XCTAssertTrue(violations.isEmpty)
    }

    // MARK: - Helpers

    private func makeTemporaryRepo(with swiftBody: String) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreferredColorSchemeGuardTests-\(UUID().uuidString)", isDirectory: true)
        let file = root
            .appendingPathComponent("Fitness Coach/Features/Demo/DemoView.swift")
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? """
        import SwiftUI
        struct DemoView: View {
            var body: some View {
        \(swiftBody)
            }
        }
        """.write(to: file, atomically: true, encoding: .utf8)
        return root
    }
}
