//
//  AdjustPlanRenderTestSupport.swift
//  Fitness CoachTests
//
//  Forma — Rendering helpers for Adjust Plan UI regression tests.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
enum AdjustPlanRenderTestSupport {

    @discardableResult
    static func assertRenders<V: View>(
        _ view: V,
        size: CGSize,
        dynamicTypeSize: DynamicTypeSize = .large,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UIImage? {
        let content = view
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .dynamicTypeSize(...AdjustPlanLayoutPolicy.maxDynamicTypeSize)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.uiImage else {
            XCTFail("Expected view to render at \(size.width)x\(size.height)", file: file, line: line)
            return nil
        }
        XCTAssertGreaterThan(image.size.width, 0, file: file, line: line)
        XCTAssertGreaterThan(image.size.height, 0, file: file, line: line)
        return image
    }

    static func regressionPreview(
        scenario: AdjustPlanRegressionScenario
    ) -> some View {
        NavigationStack {
            AdjustPlanGoalStepRegressionHost(scenario: scenario)
        }
        .formaThemePreview(appearance: scenario.appearance, palette: scenario.palette)
    }
}
