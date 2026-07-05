//
//  AdjustPlanLayoutPolicy.swift
//  Fitness Coach
//
//  Forma — Layout policy constants for Adjust Plan UI regression coverage.
//

import SwiftUI

enum AdjustPlanLayoutPolicy {

    /// Smallest common iPhone logical width (iPhone SE class).
    static let smallPhoneWidth: CGFloat = 320

    /// Standard compact iPhone width used in snapshot QA.
    static let standardPhoneWidth: CGFloat = 375

    /// Trailing column reserved for the selection checkmark on every goal card.
    static let reservedCheckmarkColumnWidth = PlanSelectableCardAccessory.selectionCheckmarkColumnWidth

    /// Fixed leading icon column width for goal option cards.
    static let goalIconColumnWidth: CGFloat = 28

    /// Minimum horizontal gap between the text column and checkmark column.
    static let goalTextToCheckmarkSpacing: CGFloat = FormaTokens.Spacing.xs

    /// Spacing between stacked goal option cards.
    static let goalCardStackSpacing: CGFloat = FormaTokens.Spacing.sm

    /// Scroll bottom inset token used by the Adjust Plan shell.
    static let scrollBottomInset: CGFloat = FormaTokens.Layout.tabBarScrollPadding

    /// Dynamic Type ceiling applied by the Edit Plan flow.
    static let maxDynamicTypeSize = DynamicTypeSize.accessibility5
}
