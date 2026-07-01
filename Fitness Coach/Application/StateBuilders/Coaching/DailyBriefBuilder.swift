//
//  DailyBriefBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic daily coaching brief (no AI).
//

import Foundation

struct TodayDailyBrief: Equatable, Sendable {
    var greeting: String
    var priorities: [String]
    var recommendation: String
}

enum DailyBriefBuilder {

    static func todayBrief(
        nutrition: DailyNutritionSummary,
        hasWorkoutToday: Bool,
        trainingFrequency: Int
    ) -> TodayDailyBrief {
        let greeting = timeBasedGreeting()
        var priorities: [String] = []

        if nutrition.remaining.protein > 30 {
            priorities.append("Aim for \(formatGrams(nutrition.targets.protein)) protein today.")
        } else {
            priorities.append("Protein is on track — keep it up.")
        }

        if nutrition.water.remainingMl > 500 {
            let liters = Double(nutrition.water.targetMl) / 1000.0
            priorities.append(String(format: "Drink %.1fL water.", liters))
        } else {
            priorities.append("Hydration is nearly complete.")
        }

        if hasWorkoutToday || isLikelyTrainingDay(frequency: trainingFrequency) {
            priorities.append("Training day — fuel with 40–60g carbs pre-workout.")
        } else if trainingFrequency > 0 {
            priorities.append("Rest or light movement — recovery supports progress.")
        }

        priorities.append("\(max(nutrition.remaining.calories, 0)) kcal remaining for today.")

        let recommendation: String
        if nutrition.isOverCalories {
            recommendation = "You're above today's target. Log honestly tonight — we care about the weekly trend, not one meal."
        } else if nutrition.remaining.protein > 50 {
            recommendation = "Anchor your next meal with protein."
        } else if nutrition.water.remainingMl > 1_000 {
            recommendation = "Pace your water earlier — don't leave it all for evening."
        } else {
            recommendation = "Stay consistent today. Small wins compound."
        }

        return TodayDailyBrief(
            greeting: greeting,
            priorities: priorities,
            recommendation: recommendation
        )
    }

    static func coachBrief(from brief: TodayDailyBrief) -> String {
        var lines = [brief.greeting, ""]
        lines.append("Today's priorities:")
        lines.append(contentsOf: brief.priorities.map { "• \($0)" })
        lines.append("")
        lines.append(brief.recommendation)
        return lines.joined(separator: "\n")
    }

    private static func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case ..<12: return "Good morning."
        case ..<17: return "Good afternoon."
        default: return "Good evening."
        }
    }

    private static func isLikelyTrainingDay(frequency: Int) -> Bool {
        guard frequency > 0 else { return false }
        let weekday = Calendar.current.component(.weekday, from: Date())
        return frequency >= 3 ? weekday == 2 || weekday == 4 || weekday == 6 : weekday == 2
    }

    private static func formatGrams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))g"
            : String(format: "%.0fg", value)
    }
}
