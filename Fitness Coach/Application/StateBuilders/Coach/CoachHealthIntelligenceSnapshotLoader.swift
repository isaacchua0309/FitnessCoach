//
//  CoachHealthIntelligenceSnapshotLoader.swift
//  Fitness Coach
//
//  Bounded Health Intelligence snapshot loading for Coach send flow.
//

import Foundation
import OSLog

enum CoachHealthIntelligenceSnapshotLoadOutcome: Equatable, Sendable {
    case success(HealthIntelligenceSnapshot?)
    case timedOut
    case failed(reason: String)
}

enum CoachHealthIntelligenceSnapshotLoader {

    /// Conservative ceiling for Coach send-path Health Intelligence composition.
    static let defaultTimeout: Duration = .milliseconds(900)

    private static let logger = Logger(
        subsystem: "Forma",
        category: "CoachHealthIntelligenceSnapshotLoader"
    )

    static func load(
        timeout: Duration = defaultTimeout,
        operation: @Sendable @escaping () async throws -> HealthIntelligenceSnapshot?
    ) async -> CoachHealthIntelligenceSnapshotLoadOutcome {
        enum PartialResult: Sendable {
            case completed(HealthIntelligenceSnapshot?)
            case timedOut
            case failed(String)
        }

        let outcome = await withTaskGroup(of: PartialResult.self) { group in
            group.addTask {
                do {
                    let snapshot = try await operation()
                    return .completed(snapshot)
                } catch {
                    return .failed(redactedFailureReason(for: error))
                }
            }

            group.addTask {
                try? await Task.sleep(for: timeout)
                return .timedOut
            }

            let first = await group.next()
            group.cancelAll()
            return first ?? .timedOut
        }

        switch outcome {
        case .completed(let snapshot):
            #if DEBUG
            logger.debug(
                "Coach HI snapshot load completed hasSnapshot=\(snapshot != nil, privacy: .public)"
            )
            #endif
            return .success(snapshot)
        case .timedOut:
            #if DEBUG
            logger.debug(
                "Coach HI snapshot load timed out timeoutMs=\(timeoutMilliseconds(timeout), privacy: .public)"
            )
            #else
            logger.debug("Coach HI snapshot load timed out")
            #endif
            return .timedOut
        case .failed(let reason):
            logger.debug("Coach HI snapshot load failed reason=\(reason, privacy: .public)")
            return .failed(reason: reason)
        }
    }

    static func redactedFailureReason(for error: Error) -> String {
        if let urlError = error as? URLError {
            return "network_\(urlError.code.rawValue)"
        }
        let typeName = String(reflecting: type(of: error))
            .split(separator: ".")
            .last
            .map(String.init) ?? "error"
        return typeName
    }

    private static func timeoutMilliseconds(_ timeout: Duration) -> Int {
        let components = timeout.components
        return components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
    }
}
