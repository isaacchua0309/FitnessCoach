//
//  OnboardingTargetWeightRulerHaptics.swift
//  Fitness Coach
//
//  Forma — Boundary-based haptics for the target-weight ruler.
//

import Foundation

/// Fires haptics only when canonical goal weight crosses 1 kg or 5 kg marks.
enum OnboardingTargetWeightRulerHaptics {

    struct BoundaryMarks: Equatable {
        var oneKg: Int?
        var fiveKg: Int?
    }

    enum Feedback: Equatable {
        case none
        case oneKg
        case fiveKg
    }

    static func oneKgMark(for kg: Double) -> Int {
        Int(floor(kg + 1e-9))
    }

    static func fiveKgMark(for kg: Double) -> Int {
        Int(floor(kg / 5.0 + 1e-9))
    }

    /// Returns the haptic to play, if any, and updates `marks` for debouncing.
    static func feedback(
        from previousKg: Double?,
        to newKg: Double,
        marks: inout BoundaryMarks
    ) -> Feedback {
        let newOne = oneKgMark(for: newKg)
        let newFive = fiveKgMark(for: newKg)

        guard let previousKg else {
            marks = BoundaryMarks(oneKg: newOne, fiveKg: newFive)
            return .none
        }

        let oldOne = marks.oneKg ?? oneKgMark(for: previousKg)
        let oldFive = marks.fiveKg ?? fiveKgMark(for: previousKg)

        marks = BoundaryMarks(oneKg: newOne, fiveKg: newFive)

        if newFive != oldFive {
            return .fiveKg
        }
        if newOne != oldOne {
            return .oneKg
        }
        return .none
    }

    static func play(_ feedback: Feedback) {
        switch feedback {
        case .none:
            break
        case .oneKg:
            OnboardingHaptics.rulerCrossedOneKgBoundary()
        case .fiveKg:
            OnboardingHaptics.rulerCrossedFiveKgBoundary()
        }
    }
}
