//
//  ReleaseLoggingGuardTests.swift
//  Fitness CoachTests
//
//  Forma — Fails when new Release-reachable logging appears outside the allowlist.
//

import XCTest

final class ReleaseLoggingGuardTests: XCTestCase {

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testReleaseLoggingAllowlistLoads() throws {
        let allowlist = try ReleaseLoggingGuard.loadAllowlist(repositoryRoot: repositoryRoot)
        XCTAssertEqual(allowlist.version, 1)
        XCTAssertFalse(allowlist.fileEntries.isEmpty)
        XCTAssertFalse(allowlist.debugOnlyFiles.isEmpty)
    }

    func testProductionSwiftHasNoUnallowlistedReleaseLogging() throws {
        let allowlist = try ReleaseLoggingGuard.loadAllowlist(repositoryRoot: repositoryRoot)
        let violations = ReleaseLoggingGuard.scan(repositoryRoot: repositoryRoot, allowlist: allowlist)

        if violations.isEmpty { return }

        let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
        XCTFail(
            """
            Found \(violations.count) Release-reachable logging site(s) outside the allowlist.

            \(report)

            How to fix:
            1. Prefer `#if DEBUG` / `#else return` for debug-only traces.
            2. Route allowed Release logs through `FormaLogRedactor` / `LogRedactor`.
            3. Add a specific entry to `Fitness CoachTests/Fixtures/ReleaseLoggingAllowlist.json` and document it in `Docs/Architecture/ReleaseLoggingAllowlist.md`.

            Do not add broad wildcard entries.
            """
        )
    }

    func testGuardDetectsUnallowlistedPrintInProductionSource() throws {
        let allowlist = try ReleaseLoggingGuard.loadAllowlist(repositoryRoot: repositoryRoot)
        let tempRoot = makeTemporaryRepo(
            with: #"""
            enum DemoLogger {
                static func event() {
                    print("secret user meal data")
                }
            }
            """#
        )

        let violations = ReleaseLoggingGuard.scan(repositoryRoot: tempRoot, allowlist: allowlist)
        XCTAssertFalse(violations.isEmpty)
        XCTAssertTrue(violations.contains { $0.site.pattern == "print" })
    }

    func testGuardIgnoresDebugOnlyPrint() throws {
        let allowlist = try ReleaseLoggingGuard.loadAllowlist(repositoryRoot: repositoryRoot)
        let tempRoot = makeTemporaryRepo(
            with: #"""
            enum DemoLogger {
                static func event() {
                    #if DEBUG
                    print("debug only")
                    #endif
                }
            }
            """#
        )

        let violations = ReleaseLoggingGuard.scan(repositoryRoot: tempRoot, allowlist: allowlist)
        XCTAssertTrue(violations.isEmpty)
    }

    func testGuardIgnoresElseReturnGatedLogger() throws {
        let allowlist = try ReleaseLoggingGuard.loadAllowlist(repositoryRoot: repositoryRoot)
        let tempRoot = makeTemporaryRepo(
            with: #"""
            import OSLog
            enum DemoLogger {
                private static let logger = Logger(subsystem: "Test", category: "Demo")
                static func emit() {
                    #if DEBUG
                    guard true else { return }
                    #else
                    return
                    #endif
                    logger.log("ok")
                }
            }
            """#
        )

        let violations = ReleaseLoggingGuard.scan(repositoryRoot: tempRoot, allowlist: allowlist)
        XCTAssertTrue(violations.isEmpty)
    }

    // MARK: - Helpers

    private func makeTemporaryRepo(with swiftBody: String) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseLoggingGuardTests-\(UUID().uuidString)", isDirectory: true)
        let file = root
            .appendingPathComponent("Fitness Coach/Features/Demo/DemoLogger.swift")
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? swiftBody.write(to: file, atomically: true, encoding: .utf8)
        return root
    }
}
