//
//  HardcodedColorGuardTests.swift
//  Fitness CoachTests
//
//  Forma — Fails when new hardcoded colors appear outside approved sources.
//

import XCTest

final class HardcodedColorGuardTests: XCTestCase {

    func testProductionSwiftHasNoDisallowedHardcodedColors() {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let violations = HardcodedColorGuard.scan(repositoryRoot: repositoryRoot)
        if violations.isEmpty { return }

        let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
        XCTFail(
            """
            Found \(violations.count) hardcoded color literal(s) outside approved palette sources.

            \(report)

            How to add a color properly:
            1. Add a semantic token to `FormaColorPalette` (and `FormaThemeColors` / `FormaTokens.Color` if needed).
            2. Define the value for every palette in `FormaPaletteCatalog` (light + dark).
            3. Use `FormaTokens.Color.<token>` or `@Environment(\\.formaColors)` in views.
            4. Update palette/guardrail tests (`FormaPaletteCatalogTests`, `FormaTokensColorTests`).

            Approved raw-color files: \(HardcodedColorGuard.approvedFileNames.sorted().joined(separator: ", "))
            See `Fitness CoachTests/TESTING.md` → “Theme color guardrail”.
            """
        )
    }

    func testGuardDetectsSampleViolation() {
        let sample = """
        Text("Oops")
            .foregroundStyle(.orange)
        """
        let violations = HardcodedColorGuard.scan(repositoryRoot: makeTemporaryRepo(with: sample))
        XCTAssertFalse(violations.isEmpty)
        XCTAssertTrue(violations.contains { $0.matchedPattern.contains("SwiftUI system color") })
    }

    func testGuardIgnoresApprovedPaletteFile() throws {
        let tempRoot = makeTemporaryRepo(with: "Text(\"OK\")")
        let paletteURL = tempRoot
            .appendingPathComponent("Fitness Coach/DesignSystem/Theme/FormaPaletteCatalog.swift")
        try FileManager.default.createDirectory(
            at: paletteURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "enum FormaPaletteCatalog { static let c = Color(red: 1, green: 0, blue: 0) }"
            .write(to: paletteURL, atomically: true, encoding: .utf8)

        let violations = HardcodedColorGuard.scan(repositoryRoot: tempRoot)
        XCTAssertTrue(violations.isEmpty)
    }

    func testGuardIgnoresPreviewBlocks() {
        let sample = """
        struct Demo: View {
            var body: some View { Text("Hi") }
        }

        #Preview {
            Text("Preview")
                .foregroundStyle(.orange)
        }
        """
        let violations = HardcodedColorGuard.scan(repositoryRoot: makeTemporaryRepo(with: sample))
        XCTAssertTrue(violations.isEmpty)
    }

    // MARK: - Helpers

    private func makeTemporaryRepo(with swiftBody: String) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HardcodedColorGuardTests-\(UUID().uuidString)", isDirectory: true)
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
