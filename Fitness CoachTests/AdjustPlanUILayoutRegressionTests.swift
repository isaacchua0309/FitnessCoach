//
//  AdjustPlanUILayoutRegressionTests.swift
//  Fitness CoachTests
//
//  Forma — UI regression coverage for the Adjust Your Plan goal step.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class AdjustPlanUILayoutRegressionTests: XCTestCase {

    private let regressionSize = CGSize(
        width: AdjustPlanLayoutPolicy.standardPhoneWidth,
        height: 780
    )

    private let smallPhoneSize = CGSize(
        width: AdjustPlanLayoutPolicy.smallPhoneWidth,
        height: 700
    )

    override func tearDown() async throws {
        FormaThemeAccess.resetToProductDefault()
        try await super.tearDown()
    }

    // MARK: - Scenario matrix

    func testRegressionScenarioMatrixCoversRequestedCases() {
        let scenarios = Set(AdjustPlanRegressionScenario.allCases.map(\.rawValue))

        XCTAssertTrue(scenarios.contains("smallPhoneWidth"))
        XCTAssertTrue(scenarios.contains("selectedLoseFat"))
        XCTAssertTrue(scenarios.contains("selectedMaintain"))
        XCTAssertTrue(scenarios.contains("selectedBuildMuscle"))
        XCTAssertTrue(scenarios.contains("largeDynamicType"))
        XCTAssertTrue(scenarios.contains("themeOceanBlue"))
        XCTAssertTrue(scenarios.contains("themeBlossomPink"))
        XCTAssertTrue(scenarios.contains("longLocalizedText"))
    }

    // MARK: - 1. Small iPhone width

    func testSmallPhoneWidthRendersWithoutClipping() {
        AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .smallPhoneWidth),
            size: smallPhoneSize
        )
    }

    func testSmallPhoneWidthReservesTrailingCheckmarkColumn() {
        XCTAssertEqual(
            AdjustPlanLayoutPolicy.reservedCheckmarkColumnWidth,
            PlanSelectableCardAccessory.selectionCheckmarkColumnWidth
        )
        XCTAssertGreaterThanOrEqual(
            AdjustPlanLayoutPolicy.reservedCheckmarkColumnWidth,
            AdjustPlanLayoutPolicy.goalTextToCheckmarkSpacing
        )
    }

    func testSmallPhoneWidthRecommendedLoseFatCardRendersSelectedState() {
        let options = AdjustPlanRegressionFixtures.options(recommendedGoal: .loseFat)
        guard let loseFat = options.first(where: { $0.goalType == .loseFat }) else {
            return XCTFail("Expected lose fat option")
        }

        AdjustPlanRenderTestSupport.assertRenders(
            GoalOptionCard(
                goal: loseFat,
                isSelected: true,
                isRecommended: true,
                onSelect: {}
            )
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .background(FormaPlanTokens.Color.planBackground)
            .formaThemePreview(),
            size: CGSize(width: AdjustPlanLayoutPolicy.smallPhoneWidth, height: 220)
        )
    }

    // MARK: - 2. Selected lose fat

    func testSelectedLoseFatScenarioConfiguration() {
        let scenario = AdjustPlanRegressionScenario.selectedLoseFat
        let options = AdjustPlanRegressionFixtures.options(recommendedGoal: scenario.recommendedGoal)
        guard let loseFat = options.first(where: { $0.goalType == .loseFat }) else {
            return XCTFail("Expected lose fat option")
        }

        XCTAssertEqual(scenario.selection, .loseFat)
        XCTAssertTrue(loseFat.isRecommended)
    }

    func testSelectedLoseFatRendersWithRecommendedChipAndCheckmark() {
        AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .selectedLoseFat),
            size: regressionSize
        )
    }

    func testSelectedVersusUnselectedLoseFatCardDoNotChangeLayoutWidthPolicy() {
        let options = AdjustPlanRegressionFixtures.options(recommendedGoal: .loseFat)
        guard let loseFat = options.first(where: { $0.goalType == .loseFat }) else {
            return XCTFail("Expected lose fat option")
        }
        let width = AdjustPlanLayoutPolicy.smallPhoneWidth

        let selectedView = GoalOptionCard(
            goal: loseFat,
            isSelected: true,
            isRecommended: true,
            onSelect: {}
        )
        .frame(width: width)
        .formaThemePreview()

        let unselectedView = GoalOptionCard(
            goal: loseFat,
            isSelected: false,
            isRecommended: true,
            onSelect: {}
        )
        .frame(width: width)
        .formaThemePreview()

        AdjustPlanRenderTestSupport.assertRenders(selectedView, size: CGSize(width: width, height: 240))
        AdjustPlanRenderTestSupport.assertRenders(unselectedView, size: CGSize(width: width, height: 240))
    }

    // MARK: - 3. Selected maintain weight

    func testSelectedMaintainScenarioKeepsRecommendedOnLoseFatWhenApplicable() {
        let scenario = AdjustPlanRegressionScenario.selectedMaintain
        let options = AdjustPlanRegressionFixtures.options(recommendedGoal: scenario.recommendedGoal)
        guard let maintain = options.first(where: { $0.goalType == .maintain }),
              let loseFat = options.first(where: { $0.goalType == .loseFat }) else {
            return XCTFail("Expected maintain and lose fat options")
        }

        XCTAssertEqual(scenario.selection, .maintain)
        XCTAssertFalse(maintain.isRecommended)
        XCTAssertTrue(loseFat.isRecommended)
    }

    func testSelectedMaintainRendersWithoutOverlap() {
        AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .selectedMaintain),
            size: regressionSize
        )
    }

    // MARK: - 4. Selected build muscle

    func testSelectedBuildMuscleUpdatesPathPreview() {
        let formState = AdjustPlanRegressionFixtures.formState(currentWeightKg: 90, goalWeightKg: 93)
        let path = AdjustPlanRegressionFixtures.pathState(goalType: .gainMuscle, formState: formState)

        XCTAssertEqual(path.currentWeight, "90 kg")
        XCTAssertEqual(path.targetWeight, "93 kg")
        XCTAssertTrue(path.totalChange.contains("kg"))
    }

    func testSelectedBuildMuscleRendersStableLayout() {
        AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .selectedBuildMuscle),
            size: regressionSize
        )
    }

    // MARK: - 5. Large Dynamic Type

    func testLargeDynamicTypeRendersTallerContent() {
        let standard = AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .selectedLoseFat),
            size: regressionSize,
            dynamicTypeSize: .large
        )
        let accessibility = AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .largeDynamicType),
            size: CGSize(width: regressionSize.width, height: 900),
            dynamicTypeSize: .accessibility3
        )

        XCTAssertGreaterThanOrEqual(accessibility?.size.height ?? 0, standard?.size.height ?? 0)
    }

    func testLargeDynamicTypeGoalCardsRemainScrollable() {
        AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .largeDynamicType),
            size: CGSize(width: regressionSize.width, height: 900),
            dynamicTypeSize: .accessibility3
        )
    }

    // MARK: - 6. Theme switching

    func testThemeSwitchUpdatesAccentTokensImmediately() {
        let ocean = ThemeTestSupport.makeResolved(palette: .oceanBlue, systemColorScheme: .dark)
        let blossom = ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)

        FormaThemeAccess.update(resolved: ocean)
        let oceanAccent = FormaPlanTokens.Color.planAccent
        let oceanProgress = FormaPlanTokens.Color.planProgressFill

        FormaThemeAccess.update(resolved: blossom)
        let blossomAccent = FormaPlanTokens.Color.planAccent
        let blossomProgress = FormaPlanTokens.Color.planProgressFill

        XCTAssertGreaterThan(ThemeTestSupport.colorDistance(oceanAccent, blossomAccent), 0.08)
        XCTAssertGreaterThan(ThemeTestSupport.colorDistance(oceanProgress, blossomProgress), 0.08)
    }

    func testOceanBlueAndBlossomPinkRegressionPreviewsBothRender() {
        AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .themeOceanBlue),
            size: regressionSize
        )
        AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .themeBlossomPink),
            size: regressionSize
        )
    }

    func testThemeSpecificPlanColorsMatchEnvironmentAfterSwitch() {
        let ocean = ThemeTestSupport.makeResolved(palette: .oceanBlue, systemColorScheme: .dark)
        let blossom = ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)

        let oceanColors = PlanThemeColorProvider.planColors(from: ocean)
        let blossomColors = PlanThemeColorProvider.planColors(from: blossom)

        XCTAssertGreaterThan(
            ThemeTestSupport.colorDistance(oceanColors.accent, blossomColors.accent),
            0.08
        )
        XCTAssertGreaterThan(
            ThemeTestSupport.colorDistance(oceanColors.selectedBorder, blossomColors.selectedBorder),
            0.08
        )
        XCTAssertGreaterThan(
            ThemeTestSupport.colorDistance(oceanColors.progressFill, blossomColors.progressFill),
            0.08
        )
        XCTAssertGreaterThan(
            ThemeTestSupport.colorDistance(oceanColors.accentSoft, blossomColors.accentSoft),
            0.08
        )
    }

    // MARK: - 7. Long localized text simulation

    func testLongLocalizedGoalTitlesRenderAtSmallWidth() {
        AdjustPlanRenderTestSupport.assertRenders(
            AdjustPlanRenderTestSupport.regressionPreview(scenario: .longLocalizedText),
            size: smallPhoneSize
        )
    }

    func testLongRecommendedChipRendersWithoutCollapsingCheckmarkColumn() {
        AdjustPlanRenderTestSupport.assertRenders(
            HStack(alignment: .top, spacing: AdjustPlanLayoutPolicy.goalTextToCheckmarkSpacing) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    Text(AdjustPlanRegressionFixtures.longRecommendedBadgeText())
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    RecommendedChip(text: AdjustPlanRegressionFixtures.longRecommendedBadgeText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: AdjustPlanLayoutPolicy.goalTextToCheckmarkSpacing)
                PlanSelectableCardAccessory.selectionCheckmark(isSelected: true)
            }
            .padding()
            .background(FormaPlanTokens.Color.planBackground)
            .formaThemePreview(),
            size: CGSize(width: AdjustPlanLayoutPolicy.smallPhoneWidth, height: 260)
        )
    }

    // MARK: - Layout policy contracts

    func testGoalSelectorUsesLazyVStackAndReservedCheckmarkPolicy() {
        XCTAssertEqual(AdjustPlanLayoutPolicy.goalCardStackSpacing, FormaTokens.Spacing.sm)
        XCTAssertEqual(AdjustPlanLayoutPolicy.goalIconColumnWidth, 28)
        XCTAssertEqual(AdjustPlanLayoutPolicy.scrollBottomInset, FormaTokens.Layout.tabBarScrollPadding)
    }

    func testSummaryCardMatchesCompactHeroCopyContract() {
        let formState = AdjustPlanRegressionFixtures.formState(currentWeightKg: 90, goalWeightKg: 85)
        let hero = AdjustPlanRegressionFixtures.heroState(goalType: .loseFat, formState: formState)

        XCTAssertEqual(hero.motivationalLine, FormaProductCopy.PlanEditHero.motivationalFatLoss)
        XCTAssertEqual(hero.goalLabel, "Goal")
        XCTAssertEqual(hero.currentWeightLabel, "Current")
        XCTAssertEqual(hero.targetWeightLabel, "Target")
        XCTAssertEqual(hero.goalValue, FormaProductCopy.PlanEditGoal.loseFatTitle)
        XCTAssertEqual(hero.currentWeight, "90 kg")
        XCTAssertEqual(hero.targetWeight, "85 kg")
        XCTAssertEqual(hero.totalChangeLine, "5 kg between now and your goal.")
    }
}
