//
//  PlanTargetRepository.swift
//  Fitness Coach
//
//  Domain protocol for plan target calculation reads (no persistence).
//

import Foundation

@MainActor
protocol PlanTargetCalculating: AnyObject {
    func generateInitialTargets(from input: CalorieTargetInput) throws -> CalorieTargetResult
}

extension TargetService: PlanTargetCalculating {}
