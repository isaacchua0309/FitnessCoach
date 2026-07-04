//
//  CoachEstimateTrustModels.swift
//  Fitness Coach
//
//  Forma — Additive trust and uncertainty models for Coach food estimates.
//

import Foundation

// MARK: - Range

enum CalorieEstimateRangeSource: String, Codable, Equatable, Sendable {
    case aiTextEstimate
    case aiPhotoEstimate
    case derivedFromConfidence
    case nutritionEstimateCard
    case localCatalog
    case userCorrected
    case unknown
}

struct CalorieEstimateRange: Codable, Equatable, Sendable {
    var estimated: Int
    var lowerBound: Int?
    var upperBound: Int?
    var source: CalorieEstimateRangeSource?

    init(
        estimated: Int,
        lowerBound: Int? = nil,
        upperBound: Int? = nil,
        source: CalorieEstimateRangeSource? = nil
    ) {
        self.estimated = max(0, estimated)
        self.lowerBound = lowerBound.map { max(0, $0) }
        self.upperBound = upperBound.map { max(0, $0) }
        self.source = source
    }

    var hasBounds: Bool {
        guard let lowerBound, let upperBound else { return false }
        return lowerBound <= upperBound
    }

    var displayText: String {
        guard hasBounds else {
            return estimated > 0 ? "~\(estimated) kcal" : "Estimated kcal"
        }
        if lowerBound == upperBound {
            return "\(lowerBound!) kcal"
        }
        return "\(lowerBound!)–\(upperBound!) kcal"
    }

    static func fromBounds(
        estimated: Int,
        lower: Int?,
        upper: Int?
    ) -> CalorieEstimateRange? {
        guard estimated > 0 || lower != nil || upper != nil else { return nil }
        let resolvedEstimated = estimated > 0 ? estimated : midpoint(lower: lower, upper: upper) ?? 0
        guard resolvedEstimated > 0 || lower != nil || upper != nil else { return nil }
        return CalorieEstimateRange(
            estimated: resolvedEstimated,
            lowerBound: lower,
            upperBound: upper
        )
    }

    private static func midpoint(lower: Int?, upper: Int?) -> Int? {
        guard let lower, let upper, lower <= upper else { return nil }
        return (lower + upper) / 2
    }
}

// MARK: - Trust metadata

enum EstimateRiskLevel: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

struct CoachEstimateTrustMetadata: Codable, Equatable, Sendable {
    var confidence: ConfidenceLevel
    var assumptions: [String]
    var uncertaintyReasons: [String]
    var suggestedClarifications: [String]
    var requiresClarificationBeforeLogging: Bool
    var primaryUncertainty: String?
    var riskLevel: EstimateRiskLevel?

    init(
        confidence: ConfidenceLevel = .medium,
        assumptions: [String] = [],
        uncertaintyReasons: [String] = [],
        suggestedClarifications: [String] = [],
        requiresClarificationBeforeLogging: Bool = false,
        primaryUncertainty: String? = nil,
        riskLevel: EstimateRiskLevel? = nil
    ) {
        self.confidence = confidence
        self.assumptions = assumptions
        self.uncertaintyReasons = uncertaintyReasons
        self.suggestedClarifications = suggestedClarifications
        self.requiresClarificationBeforeLogging = requiresClarificationBeforeLogging
        self.primaryUncertainty = primaryUncertainty
        self.riskLevel = riskLevel
    }

    var isSafeToPresentDirectly: Bool {
        !requiresClarificationBeforeLogging
    }
}

struct ComponentEstimateTrustMetadata: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var componentName: String
    var estimatedCalories: Int
    var rangeLower: Int?
    var rangeUpper: Int?
    var assumptions: [String]
    var uncertaintyReasons: [String]

    init(
        id: UUID = UUID(),
        componentName: String,
        estimatedCalories: Int,
        rangeLower: Int? = nil,
        rangeUpper: Int? = nil,
        assumptions: [String] = [],
        uncertaintyReasons: [String] = []
    ) {
        self.id = id
        self.componentName = componentName
        self.estimatedCalories = max(0, estimatedCalories)
        self.rangeLower = rangeLower.map { max(0, $0) }
        self.rangeUpper = rangeUpper.map { max(0, $0) }
        self.assumptions = assumptions
        self.uncertaintyReasons = uncertaintyReasons
    }

    var calorieRange: CalorieEstimateRange? {
        CalorieEstimateRange.fromBounds(
            estimated: estimatedCalories,
            lower: rangeLower,
            upper: rangeUpper
        )
    }
}

// MARK: - FoodLogDraft trust surface

extension FoodLogDraft {

    var calorieRange: CalorieEstimateRange? {
        CalorieEstimateRange.fromBounds(
            estimated: totalCalories,
            lower: calorieRangeLower,
            upper: calorieRangeUpper
        )
    }

    var estimateTrust: CoachEstimateTrustMetadata {
        CoachEstimateTrustMetadata(
            confidence: confidence,
            assumptions: assumptions,
            uncertaintyReasons: uncertaintyReasons,
            suggestedClarifications: suggestedClarifications,
            requiresClarificationBeforeLogging: requiresClarificationBeforeLogging,
            primaryUncertainty: primaryUncertainty,
            riskLevel: riskLevel
        )
    }

    var isSafeToPresentDirectly: Bool {
        !requiresClarificationBeforeLogging
    }

    /// Committed logging still uses scalar component sums.
    var committedCalorieTotal: Int {
        totalCalories
    }

    func applyingEstimateTrust(_ metadata: CoachEstimateTrustMetadata) -> FoodLogDraft {
        var copy = self
        copy.confidence = metadata.confidence
        copy.assumptions = metadata.assumptions
        copy.uncertaintyReasons = metadata.uncertaintyReasons
        copy.suggestedClarifications = metadata.suggestedClarifications
        copy.requiresClarificationBeforeLogging = metadata.requiresClarificationBeforeLogging
        copy.primaryUncertainty = metadata.primaryUncertainty
        copy.riskLevel = metadata.riskLevel
        return copy
    }

    func applyingCalorieRange(_ range: CalorieEstimateRange?) -> FoodLogDraft {
        var copy = self
        copy.calorieRangeLower = range?.lowerBound
        copy.calorieRangeUpper = range?.upperBound
        return copy
    }

    func preservingEstimateTrustFields(from original: FoodLogDraft) -> FoodLogDraft {
        var copy = self
        copy.calorieRangeLower = original.calorieRangeLower
        copy.calorieRangeUpper = original.calorieRangeUpper
        copy.assumptions = original.assumptions
        copy.uncertaintyReasons = original.uncertaintyReasons
        copy.suggestedClarifications = original.suggestedClarifications
        copy.primaryUncertainty = original.primaryUncertainty
        copy.requiresClarificationBeforeLogging = original.requiresClarificationBeforeLogging
        copy.riskLevel = original.riskLevel
        copy.componentTrustMetadata = original.componentTrustMetadata
        return copy
    }
}

extension FoodComponent {

    static func componentTrustMetadata(
        for component: FoodComponent,
        assumptions: [String] = [],
        uncertaintyReasons: [String] = []
    ) -> ComponentEstimateTrustMetadata {
        let mergedAssumptions: [String]
        if assumptions.isEmpty, let sourceText = component.sourceText?.trimmingCharacters(in: .whitespacesAndNewlines), !sourceText.isEmpty {
            mergedAssumptions = [sourceText]
        } else {
            mergedAssumptions = assumptions
        }
        return ComponentEstimateTrustMetadata(
            componentName: component.name,
            estimatedCalories: component.calories,
            assumptions: mergedAssumptions,
            uncertaintyReasons: uncertaintyReasons
        )
    }
}
