//
//  CoachContextFoodCorrectionMemoryBuilder.swift
//  Fitness Coach
//
//  Forma — Maps local food correction memory into CoachContextPacketV2 hints.
//

import Foundation

enum CoachContextFoodCorrectionMemoryBuilder {

    static let hintsNotFactsAssumptionKey = "foodCorrectionMemory"

    static func makeContextEntries(
        from entries: [FoodCorrectionMemoryEntry],
        limit: Int = FoodCorrectionMemoryLimits.maxContextEntries
    ) -> [CoachFoodCorrectionContext] {
        guard limit > 0, !entries.isEmpty else { return [] }

        return entries
            .sorted { lhs, rhs in
                if lhs.useCount == rhs.useCount {
                    let lhsDate = lhs.lastUsedAt ?? lhs.createdAt
                    let rhsDate = rhs.lastUsedAt ?? rhs.createdAt
                    return lhsDate > rhsDate
                }
                return lhs.useCount > rhs.useCount
            }
            .prefix(limit)
            .map { entry in
                CoachFoodCorrectionContext(
                    patternSummary: contextSummary(for: entry),
                    foodKey: entry.normalizedFoodKey,
                    correctionType: entry.correctionType.rawValue,
                    componentName: entry.componentName,
                    amountHint: entry.amountHint,
                    useCount: entry.useCount,
                    lastUsedAt: entry.lastUsedAt ?? entry.createdAt,
                    confidence: .medium
                )
            }
    }

    static func hintsNotFactsAssumption() -> CoachAssumptionContext {
        CoachAssumptionContext(
            key: hintsNotFactsAssumptionKey,
            detail: "Food correction memory contains user-specific hints only. Use as guidance, not guaranteed facts.",
            confidence: .high
        )
    }

    // MARK: - Private

    private static func contextSummary(for entry: FoodCorrectionMemoryEntry) -> String {
        let trimmed = entry.correctionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "User corrected \(entry.originalFoodName) recently."
        }

        if trimmed.lowercased().hasPrefix("user ") {
            return trimmed
        }
        return "User \(trimmed.prefix(1).lowercased() + trimmed.dropFirst())"
    }
}
