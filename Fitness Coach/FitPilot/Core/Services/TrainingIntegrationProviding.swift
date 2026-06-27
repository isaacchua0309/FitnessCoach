//
//  TrainingIntegrationProviding.swift
//  Fitness Coach
//
//  Forma — Boundary for Apple Health training integration (Stage 2).
//

import Foundation

/// Reads and updates Apple Health connection state without exposing HealthKit types.
protocol TrainingIntegrationProviding: Sendable {

    /// Backend that should supply official training insights on this device.
    var dataSource: TrainingDataSource { get }

    /// Reconcile integration state from persistence or HealthKit (stub until Stage 3).
    func refreshState() async -> TrainingIntegrationState

    /// Begin the Apple Health permission flow (stub until Stage 3).
    func requestConnection() async -> TrainingIntegrationState
}
