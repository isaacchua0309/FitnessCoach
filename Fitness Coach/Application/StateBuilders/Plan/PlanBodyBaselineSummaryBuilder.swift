//
//  PlanBodyBaselineSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Body baseline summary for Edit Plan height & weight step.
//

import Foundation

struct PlanBodyBaselineSummaryState: Equatable, Sendable {
    let heightDisplay: String
    let weightDisplay: String
    let bodyContextLine: String?
    let maintenancePreviewLine: String?
    let coachingLine: String
    let isComplete: Bool
}

struct PlanBodyBaselineProjectionState: Equatable, Sendable {
    let maintenanceLine: String?
    let adjustmentLine: String
    let isPlaceholder: Bool
}

enum PlanBodyBaselineSummaryBuilder {

    static func summary(
        formState: PlanFormState,
        projection: PlanProjection
    ) -> PlanBodyBaselineSummaryState {
        let copy = FormaProductCopy.PlanEditBodyBaseline.self
        let heightDisplay = formattedHeight(formState.heightCmText)
        let weightDisplay = formattedWeight(
            formState.currentWeightKgText,
            unitSystem: formState.unitSystem
        )

        let bodyContext = bodyContextLine(
            heightDisplay: heightDisplay,
            weightDisplay: weightDisplay
        )

        let maintenancePreview = maintenancePreviewLine(
            formState: formState,
            projection: projection
        )

        let isComplete = heightDisplay != copy.unavailablePlaceholder
            && weightDisplay != copy.unavailablePlaceholder

        return PlanBodyBaselineSummaryState(
            heightDisplay: heightDisplay,
            weightDisplay: weightDisplay,
            bodyContextLine: bodyContext,
            maintenancePreviewLine: maintenancePreview,
            coachingLine: copy.coachingLine,
            isComplete: isComplete
        )
    }

    static func projection(
        formState: PlanFormState,
        projection: PlanProjection
    ) -> PlanBodyBaselineProjectionState {
        let copy = FormaProductCopy.PlanEditBodyBaseline.self

        guard let maintenance = PlanBodyBaselineMaintenanceEstimator.maintenanceKcal(
            formState: formState,
            projection: projection
        ) else {
            return PlanBodyBaselineProjectionState(
                maintenanceLine: nil,
                adjustmentLine: copy.targetAdjustedFromBaseline,
                isPlaceholder: true
            )
        }

        let formatted = PlanDisplayFormatter.formatKcalPerDay(maintenance)
        return PlanBodyBaselineProjectionState(
            maintenanceLine: copy.maintenanceAtBaseline(formatted),
            adjustmentLine: copy.targetAdjustedFromBaseline,
            isPlaceholder: false
        )
    }

    private static func bodyContextLine(
        heightDisplay: String,
        weightDisplay: String
    ) -> String? {
        let copy = FormaProductCopy.PlanEditBodyBaseline.self
        guard heightDisplay != copy.unavailablePlaceholder,
              weightDisplay != copy.unavailablePlaceholder else {
            return nil
        }
        return copy.bodyProfileContext(height: heightDisplay, weight: weightDisplay)
    }

    private static func maintenancePreviewLine(
        formState: PlanFormState,
        projection: PlanProjection
    ) -> String? {
        let copy = FormaProductCopy.PlanEditBodyBaseline.self
        guard let maintenance = PlanBodyBaselineMaintenanceEstimator.maintenanceKcal(
            formState: formState,
            projection: projection
        ) else {
            return nil
        }
        return copy.maintenancePreviewValue(
            PlanDisplayFormatter.formatKcalPerDay(maintenance)
        )
    }

    private static func formattedHeight(_ text: String) -> String {
        guard let value = parsedPositive(text) else {
            return FormaProductCopy.PlanEditBodyBaseline.unavailablePlaceholder
        }
        return PlanFormatter.cm(value)
    }

    private static func formattedWeight(_ text: String, unitSystem: UnitSystem) -> String {
        guard let value = parsedPositive(text) else {
            return FormaProductCopy.PlanEditBodyBaseline.unavailablePlaceholder
        }
        switch unitSystem {
        case .metric:
            return PlanFormatter.kg(value)
        case .imperial:
            return OnboardingGoalWeightBounds.weightSummary(valueKg: value, unitSystem: .imperial)
        }
    }

    private static func parsedPositive(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
}

private extension FormaProductCopy.PlanEditBodyBaseline {
    static let unavailablePlaceholder = "—"
}
