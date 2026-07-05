//
//  HealthIntelligencePresentationLifecycle.swift
//  Fitness Coach
//
//  Forma — Shared Health Intelligence UI lifecycle states across Today, Journey, Plan, and Coach.
//

import Foundation

enum HealthIntelligencePresentationLifecycle: String, Equatable, Sendable, Codable, CaseIterable {
    case loading
    case ready
    case noHealthPermission
    case partialHealthPermission
    case noHealthDataYet
    case limitedEstimate
    case syncFailed
    case unavailableOnDevice
}

enum HealthIntelligencePresentationAction: String, Equatable, Sendable, Codable {
    case connectAppleHealth
    case manageHealthPermissions
    case continueLogging
    case askCoach
    case none
}

enum HealthIntelligenceSurface: String, Equatable, Sendable, Codable {
    case today
    case journey
    case plan
    case coach
}

struct HealthIntelligencePresentationContext: Equatable, Sendable {
    var isLoading: Bool = false
    var explicitErrorMessage: String? = nil
    var syncPhase: HealthSyncPhase? = nil
    var availability: HealthDataAvailability? = nil
    var snapshot: HealthIntelligenceSnapshot? = nil
    var isAppleHealthConnected: Bool = false
    var cachedDayCount: Int = 0
    var trainingIntegrationState: TrainingIntegrationState = .notConnected
    var connectionRecord: HealthIntegrationConnectionRecord = .empty
    var baseline: HealthBaselineContext? = nil
}

struct HealthIntelligencePresentationMessage: Equatable, Sendable {
    let lifecycle: HealthIntelligencePresentationLifecycle
    let title: String
    let message: String
    let reassurance: String?
    let primaryAction: HealthIntelligencePresentationAction
    let primaryActionTitle: String?
}

extension HealthIntelligencePresentationMessage {
    var bannerMessage: String {
        guard let reassurance, !reassurance.isEmpty else { return message }
        return "\(message) \(reassurance)"
    }

    var accessibilityLabel: String {
        [title, message, reassurance, primaryActionTitle]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }
}
