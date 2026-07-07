//
//  PlanLayoutGuardTests.swift
//  Fitness CoachTests
//
//  Guardrails for Plan tab header Adjust/settings behavior after layout migration.
//

import XCTest

final class PlanLayoutGuardTests: XCTestCase {

    func testPlanProductionSourcesPreserveAdjustAndSettingsWiring() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let violations = PlanLayoutGuard.scan(repositoryRoot: root)
        if violations.isEmpty { return }

        XCTFail(
            """
            Found \(violations.count) Plan layout guard violation(s).

            \(violations.joined(separator: "\n"))
            """
        )
    }

    func testGuardDetectsDominantHeaderGearRegression() {
        let sample = """
        struct Demo: View {
            var body: some View {
                Image(systemName: "gearshape")
            }
        }
        """
        let violations = PlanLayoutGuard.scan(repositoryRoot: makeTemporaryPlanRepo(with: sample))
        XCTAssertTrue(violations.contains { $0.contains("dominant gear icon") })
    }

    private func makeTemporaryPlanRepo(with planViewSource: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let planDirectory = directory.appendingPathComponent("Fitness Coach/Features/Plan", isDirectory: true)
        try! FileManager.default.createDirectory(at: planDirectory, withIntermediateDirectories: true)
        let planViewURL = planDirectory.appendingPathComponent("PlanView.swift")
        try! planViewSource.write(to: planViewURL, atomically: true, encoding: .utf8)
        return directory
    }
}
