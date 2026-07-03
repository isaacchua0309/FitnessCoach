//
//  TodayMealsSectionFormatting.swift
//  Fitness Coach
//
//  Forma — Display models for the Today meals section.
//

import Foundation

struct TodayMealRowDisplayModel: Equatable, Sendable {
    var title: String
    var statusLine: String
    var detailLine: String?
    var showsCheckmark: Bool
    var showsAddAction: Bool
    var isOptional: Bool
    var accessibilityLabel: String
    var accessibilityHint: String?
}

enum TodayMealsSectionFormatting {

    static func rowDisplayModel(for group: TodayMealGroupState) -> TodayMealRowDisplayModel {
        if group.isLogged {
            return loggedRow(for: group)
        }
        return emptyRow(for: group)
    }

    static func emptyRow(for group: TodayMealGroupState) -> TodayMealRowDisplayModel {
        let title = FormaProductCopy.Today.Meals.mealTitle(group.mealType, isOptional: group.isOptional)
        var parts = [title, FormaProductCopy.Today.Meals.readyStatus]
        if group.isOptional {
            parts.append(FormaProductCopy.Today.Meals.optionalLabel)
        }

        return TodayMealRowDisplayModel(
            title: title,
            statusLine: FormaProductCopy.Today.Meals.readyStatus,
            detailLine: nil,
            showsCheckmark: false,
            showsAddAction: true,
            isOptional: group.isOptional,
            accessibilityLabel: parts.joined(separator: ". "),
            accessibilityHint: FormaProductCopy.Today.Meals.addAccessibilityHint
        )
    }

    static func loggedRow(for group: TodayMealGroupState) -> TodayMealRowDisplayModel {
        let title = FormaProductCopy.Today.Meals.mealTitle(group.mealType, isOptional: group.isOptional)
        let caloriesLine = FormaProductCopy.Today.Meals.caloriesLine(group.totalCalories)
        let proteinLine = FormaProductCopy.Today.Meals.proteinLine(group.totalProtein)

        var accessibilityParts = [title, caloriesLine, proteinLine, FormaProductCopy.Today.Meals.loggedAccessibilityValue]
        if group.isOptional {
            accessibilityParts.insert(FormaProductCopy.Today.Meals.optionalLabel, at: 1)
        }
        if group.hasMultipleEntries {
            accessibilityParts.append(
                FormaProductCopy.Today.Meals.multipleItemsAccessibilityLabel(group.entries.count)
            )
        }

        return TodayMealRowDisplayModel(
            title: title,
            statusLine: caloriesLine,
            detailLine: proteinLine,
            showsCheckmark: true,
            showsAddAction: false,
            isOptional: group.isOptional,
            accessibilityLabel: accessibilityParts.joined(separator: ". "),
            accessibilityHint: FormaProductCopy.Today.Meals.editAccessibilityHint
        )
    }
}
