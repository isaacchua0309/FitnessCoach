//
//  JourneyLayoutTests.swift
//  Fitness CoachTests
//
//  Forma — Journey scroll clearance and layout constants.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class JourneyLayoutTests: XCTestCase {

    func testScrollBottomInsetIncludesTabBarSafeAreaAndBreathingRoom() {
        let bottomSafeArea = FormaTokens.Layout.homeIndicatorSafeAreaEstimate
        let inset = JourneyLayout.scrollBottomInset(
            bottomSafeArea: bottomSafeArea,
            dynamicTypeSize: .large
        )

        XCTAssertEqual(
            inset,
            FormaTokens.Layout.floatingTabBarHeight
                + bottomSafeArea
                + JourneyLayout.tabBarBreathingRoom
        )
    }

    func testScrollBottomInsetGrowsForAccessibilitySizes() {
        let bottomSafeArea: CGFloat = 34
        let standard = JourneyLayout.scrollBottomInset(
            bottomSafeArea: bottomSafeArea,
            dynamicTypeSize: .large
        )
        let accessibility = JourneyLayout.scrollBottomInset(
            bottomSafeArea: bottomSafeArea,
            dynamicTypeSize: .accessibility3
        )

        XCTAssertGreaterThan(accessibility, standard)
    }

    func testJourneyScrollBottomInsetMatchesSharedTokenFormula() {
        let bottomSafeArea: CGFloat = 0
        XCTAssertEqual(
            FormaTokens.Layout.journeyScrollBottomInset(
                bottomSafeArea: bottomSafeArea,
                breathingRoom: JourneyLayout.tabBarBreathingRoom
            ),
            FormaTokens.Layout.floatingTabBarHeight + JourneyLayout.tabBarBreathingRoom
        )
    }

    func testTabBarBreathingRoomIsWithinProductRange() {
        XCTAssertGreaterThanOrEqual(JourneyLayout.tabBarBreathingRoom, 24)
        XCTAssertLessThanOrEqual(JourneyLayout.tabBarBreathingRoom, 32)
    }
}
