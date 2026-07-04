//
//  PlanEditAccessibilityTests.swift
//  Fitness CoachTests
//
//  Forma — Edit Plan accessibility contract and contrast checks.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class PlanEditAccessibilityTests: XCTestCase {

    override func tearDown() async throws {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()
        }
        try await super.tearDown()
    }

    // MARK: - VoiceOver selection state

    func testSelectionValueUsesExplicitSelectedAndNotSelectedCopy() {
        XCTAssertEqual(
            PlanEditAccessibility.selectionValue(isSelected: true),
            FormaProductCopy.PlanEditAccessibility.selected
        )
        XCTAssertEqual(
            PlanEditAccessibility.selectionValue(isSelected: false),
            FormaProductCopy.PlanEditAccessibility.notSelected
        )
    }

    func testProgressValueUsesStepCopy() {
        XCTAssertEqual(
            PlanEditAccessibility.progressValue(currentStep: 1, stepCount: 5),
            "Step 2 of 5"
        )
        XCTAssertEqual(
            PlanEditAccessibility.progressValue(currentStep: 0, stepCount: 0),
            "Step 1 of 1"
        )
    }

    func testFieldLabelIncludesUnitWhenProvided() {
        XCTAssertEqual(
            FormaProductCopy.PlanEditAccessibility.fieldLabel(title: "Height", unit: "cm"),
            "Height, cm"
        )
        XCTAssertEqual(
            FormaProductCopy.PlanEditAccessibility.fieldLabel(title: "Age", unit: nil),
            "Age"
        )
        XCTAssertEqual(
            FormaProductCopy.PlanEditAccessibility.fieldLabel(title: "Weight", unit: ""),
            "Weight"
        )
    }

    func testSelectionPolicyDocumentsNonColorCues() {
        XCTAssertTrue(PlanEditSelectionAccessibilityPolicy.includesCheckmarkForSelectedState)
        XCTAssertTrue(PlanEditSelectionAccessibilityPolicy.includesSelectedTraitForSelectedState)
        XCTAssertTrue(PlanEditSelectionAccessibilityPolicy.includesSelectionInAccessibilityValue)
        XCTAssertTrue(PlanEditSelectionAccessibilityPolicy.includesBorderForSelectedState)
        XCTAssertTrue(PlanEditSelectionAccessibilityPolicy.meetsMinimumTouchTarget)
    }

    func testMinimumTouchTargetMeetsHIG() {
        XCTAssertGreaterThanOrEqual(PlanEditAccessibility.minimumTouchTarget, 44)
        XCTAssertEqual(PlanEditAccessibility.minimumTouchTarget, FormaTokens.Layout.minTouchTarget)
    }

    // MARK: - Warning card contrast

    func testWarningCardBodyTextMeetsContrastOnSoftBackgroundAcrossPalettes() async {
        await MainActor.run {
            for palette in AppThemePalette.allCases {
                for scheme in [ColorScheme.light, ColorScheme.dark] {
                    let resolved = ThemeResolver.resolve(
                        preferences: AppThemePreferences(appearance: .dark, palette: palette),
                        systemColorScheme: scheme
                    )
                    let planColors = PlanThemeColorProvider.planColors(from: resolved)

                    XCTAssertTrue(
                        FormaColorContrast.meetsWCAGAA(
                            foreground: planColors.planPrimaryText,
                            background: planColors.planWarningSoft,
                            minimumRatio: 4.5
                        ),
                        "Warning body text contrast failed for \(palette.rawValue) \(scheme)"
                    )
                    XCTAssertTrue(
                        FormaColorContrast.meetsWCAGAA(
                            foreground: planColors.planWarning,
                            background: planColors.planWarningSoft,
                            minimumRatio: 3.0
                        ),
                        "Warning title contrast failed for \(palette.rawValue) \(scheme)"
                    )
                }
            }
        }
    }
}
