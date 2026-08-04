//
//  AccountRestoreBootstrapTracer.swift
//  Fitness Coach
//
//  Forma — DEBUG-only stage timing for account restore bootstrap.
//
//  Logs aggregate durations only. Never logs profile names, food content,
//  weights, HealthKit samples, or full UIDs.
//

import Foundation

enum AccountRestoreBootstrapTracer {

    /// Records a restore stage duration when account-restore tracing is enabled.
    nonisolated static func measure<T>(
        _ stage: String,
        fields: [String: String] = [:],
        operation: () async throws -> T
    ) async rethrows -> T {
        #if DEBUG
        let start = ContinuousClock.now
        do {
            let value = try await operation()
            emit(stage: stage, start: start, fields: fields, cancelled: false)
            return value
        } catch {
            emit(stage: stage, start: start, fields: fields, cancelled: Task.isCancelled)
            throw error
        }
        #else
        return try await operation()
        #endif
    }

    /// Non-throwing variant for restore stages that swallow errors internally.
    nonisolated static func measure(
        _ stage: String,
        fields: [String: String] = [:],
        operation: () async -> Void
    ) async {
        #if DEBUG
        let start = ContinuousClock.now
        await operation()
        emit(stage: stage, start: start, fields: fields, cancelled: Task.isCancelled)
        #else
        await operation()
        #endif
    }

    nonisolated static func event(_ stage: String, fields: [String: String] = [:]) {
        #if DEBUG
        var merged = fields
        merged["stage"] = stage
        AccountRestoreLogger.event("bootstrap_stage", fields: merged)
        #endif
    }

    #if DEBUG
    nonisolated private static func emit(
        stage: String,
        start: ContinuousClock.Instant,
        fields: [String: String],
        cancelled: Bool
    ) {
        let duration = start.duration(to: .now)
        let durationMs = max(0, Int(duration / .milliseconds(1)))
        var merged = fields
        merged["stage"] = stage
        merged["durationMs"] = String(durationMs)
        if cancelled {
            merged["cancelled"] = "true"
        }
        AccountRestoreLogger.event("bootstrap_stage", fields: merged)
    }
    #endif
}
