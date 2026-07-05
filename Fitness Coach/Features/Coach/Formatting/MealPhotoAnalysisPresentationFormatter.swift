//
//  MealPhotoAnalysisPresentationFormatter.swift
//  Fitness Coach
//
//  Trust-aware assistant copy for meal photo analysis messages.
//

import Foundation

enum MealPhotoAnalysisPresentationFormatter {

    static func assistantMessage(
        mealDraft: FoodLogDraft,
        confidence: AIConfidence,
        trust: MealImageAnalysisTrustMetadata,
        sanityWarning: String? = nil
    ) -> String {
        var sections: [String] = [
            MealImageAnalysisTrustPolicy.estimatedFromPhotoMessage,
            MealImageAnalysisTrustPolicy.photoReviewRequiredMessage
        ]

        let range = FoodCalorieRange(
            lower: trust.calorieRangeLower,
            upper: trust.calorieRangeUpper
        )
        sections.append("Likely range: \(range.lower)-\(range.upper) kcal")

        if let primaryUncertainty = trust.primaryUncertainty, !primaryUncertainty.isEmpty {
            sections.append("Main uncertainty: \(primaryUncertainty)")
        } else if let firstReason = trust.uncertaintyReasons.first {
            sections.append("Main uncertainty: \(firstReason)")
        }

        if !trust.presentationWarnings.isEmpty {
            sections.append("")
            sections.append(contentsOf: trust.presentationWarnings)
        }

        if !trust.assumptions.isEmpty {
            sections.append("")
            sections.append("Assumptions:")
            sections.append(contentsOf: trust.assumptions.prefix(3).map { "• \($0)" })
        }

        sections.append("")
        sections.append(
            CoachPendingCopyFormatter.foodHeadline(
                mealDraft: mealDraft,
                tone: .standard,
                fromPhotoAnalysis: true
            )
        )
        sections.append(
            CoachPendingCopyFormatter.chatNutritionLine(for: mealDraft, style: .full)
        )

        if let sanityWarning, !sanityWarning.isEmpty {
            sections.append("")
            sections.append(sanityWarning)
        }

        sections.append("")
        sections.append(AIFoodConfirmationFormatter.confidenceLabel(confidence))
        sections.append(FormaProductCopy.Coach.foodEditPortionFooter)

        return sections.joined(separator: "\n")
    }
}
