//
//  HealthIntelligenceUIState.swift
//  Fitness Coach
//
//  Forma — Centralized Health Intelligence UI state for Today, Journey, Plan, and Coach.
//

import Foundation

enum HealthIntelligenceUIStateKind: String, Equatable, Sendable, Codable, CaseIterable {
    case loading
    case ready
    case noHealthPermission
    case partialPermission
    case healthKitUnavailable
    case noWorkoutHistory
    case noSleepData
    case noHeartData
    case notEnoughBaseline
    case syncFailed
    case staleData
    case remoteSyncDisabled
    case unknown
}

enum HealthIntelligenceUIAction: String, Equatable, Sendable, Codable {
    case none
    case connectAppleHealth
    case manageHealthPermissions
    case refreshHealthData
    case manageHealthDataSync
    case continueLogging
    case askCoach
    case retrySync
    case openPlan
}

enum HealthIntelligenceUISeverity: String, Equatable, Sendable, Codable {
    case info
    case warning
    case error
}

struct HealthIntelligenceUIContext: Equatable, Sendable {
    var isLoading: Bool = false
    var explicitErrorMessage: String? = nil
    var syncPhase: HealthSyncPhase? = nil
    var lastSuccessfulLocalSyncAt: Date? = nil
    var isRemoteSyncCapabilityEnabled: Bool = false
    var isRemoteSyncUserEnabled: Bool = false
    var remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined
    var availability: HealthDataAvailability? = nil
    var snapshot: HealthIntelligenceSnapshot? = nil
    var baseline: HealthBaselineContext? = nil
    var isAppleHealthConnected: Bool = false
    var cachedDayCount: Int = 0
    var surface: HealthIntelligenceSurface = .today
    var now: Date = Date()
    var staleAfter: TimeInterval = HealthIntelligenceUIStatePolicy.defaultStaleInterval
}

enum HealthIntelligenceUIStatePolicy {
    static let defaultStaleInterval: TimeInterval = 24 * 60 * 60
    static let minimumBaselineDays = 7
}

struct HealthIntelligenceUIState: Equatable, Sendable, Codable {
    let kind: HealthIntelligenceUIStateKind
    let title: String
    let message: String
    let primaryActionTitle: String?
    let secondaryActionTitle: String?
    let primaryAction: HealthIntelligenceUIAction
    let secondaryAction: HealthIntelligenceUIAction
    let severity: HealthIntelligenceUISeverity
    let canShowInsight: Bool
    let confidenceLabel: String?
    let missingSignals: [HealthInsightAvailability]
    let fallbackReason: HealthFallbackReason

    var missingInsightKinds: [HealthInsightKind] {
        missingSignals.filter(\.isMissing).map(\.kind)
    }
}

enum HealthIntelligenceUIStateMapper {

    static func resolve(_ context: HealthIntelligenceUIContext) -> HealthIntelligenceUIState {
        let kind = resolveKind(context)
        let copy = FormaProductCopy.HealthIntelligence.UIState.message(
            for: kind,
            surface: context.surface,
            explicitErrorMessage: context.explicitErrorMessage
        )
        let missingSignals = HealthInsightAvailabilityResolver.missing(from: context)
        let confidenceLabel = confidenceLabel(for: kind, context: context)
        let canShowInsight = canShowInsight(for: kind, context: context)

        return HealthIntelligenceUIState(
            kind: kind,
            title: copy.title,
            message: composedMessage(copy: copy),
            primaryActionTitle: copy.primaryActionTitle,
            secondaryActionTitle: copy.secondaryActionTitle,
            primaryAction: copy.primaryAction,
            secondaryAction: copy.secondaryAction,
            severity: severity(for: kind),
            canShowInsight: canShowInsight,
            confidenceLabel: confidenceLabel,
            missingSignals: missingSignals,
            fallbackReason: fallbackReason(for: kind)
        )
    }

    // MARK: - Kind resolution

    static func resolveKind(_ context: HealthIntelligenceUIContext) -> HealthIntelligenceUIStateKind {
        if context.isLoading || context.syncPhase == .syncing {
            return .loading
        }

        if context.explicitErrorMessage != nil || context.syncPhase == .failed {
            return .syncFailed
        }

        if context.availability?.isHealthDataAvailable == false {
            return .healthKitUnavailable
        }

        if requiresHealthPermission(context) {
            return .noHealthPermission
        }

        if hasPartialHealthPermission(context) {
            return .partialPermission
        }

        if isStale(context) {
            return .staleData
        }

        if isRemoteSyncDisabled(context) {
            return .remoteSyncDisabled
        }

        if hasInsufficientBaseline(context) {
            return .notEnoughBaseline
        }

        if hasNoWorkoutHistory(context) {
            return .noWorkoutHistory
        }

        if hasMissingSleepData(context) {
            return .noSleepData
        }

        if hasMissingHeartData(context) {
            return .noHeartData
        }

        if hasRenderableInsight(context) {
            return .ready
        }

        if context.snapshot == nil {
            return .unknown
        }

        return .unknown
    }

    // MARK: - Private helpers

    private static func composedMessage(copy: HealthIntelligenceUIStateMessage) -> String {
        guard let reassurance = copy.reassurance, !reassurance.isEmpty else {
            return copy.message
        }
        return "\(copy.message) \(reassurance)"
    }

    private static func severity(for kind: HealthIntelligenceUIStateKind) -> HealthIntelligenceUISeverity {
        switch kind {
        case .loading, .ready, .remoteSyncDisabled:
            return .info
        case .partialPermission, .noWorkoutHistory, .noSleepData, .noHeartData,
             .notEnoughBaseline, .staleData, .unknown:
            return .warning
        case .noHealthPermission, .healthKitUnavailable, .syncFailed:
            return .error
        }
    }

    private static func canShowInsight(
        for kind: HealthIntelligenceUIStateKind,
        context: HealthIntelligenceUIContext
    ) -> Bool {
        switch kind {
        case .ready:
            return true
        case .partialPermission, .noWorkoutHistory, .noSleepData, .noHeartData,
             .notEnoughBaseline, .staleData, .remoteSyncDisabled, .unknown:
            return hasRenderableInsight(context)
        case .loading, .noHealthPermission, .healthKitUnavailable, .syncFailed:
            return false
        }
    }

    private static func confidenceLabel(
        for kind: HealthIntelligenceUIStateKind,
        context: HealthIntelligenceUIContext
    ) -> String? {
        switch kind {
        case .ready:
            if let recovery = context.snapshot?.recovery {
                if recovery.confidence == .low || recovery.confidence == .unknown {
                    return FormaProductCopy.HealthIntelligence.limitedEstimateLabel
                }
                if !recovery.missingSignals.isEmpty {
                    return FormaProductCopy.HealthIntelligence.partialDataLabel
                }
            }
            return nil
        case .partialPermission, .noSleepData, .noHeartData, .notEnoughBaseline, .staleData:
            return FormaProductCopy.HealthIntelligence.partialDataLabel
        case .noWorkoutHistory, .remoteSyncDisabled, .unknown:
            return FormaProductCopy.HealthIntelligence.buildingLabel
        default:
            return nil
        }
    }

    private static func fallbackReason(for kind: HealthIntelligenceUIStateKind) -> HealthFallbackReason {
        switch kind {
        case .loading:
            return .loading
        case .ready:
            return .none
        case .noHealthPermission:
            return .permissionsRequired
        case .partialPermission:
            return .partialPermissions
        case .healthKitUnavailable:
            return .healthKitUnavailable
        case .noWorkoutHistory:
            return .noWorkoutHistory
        case .noSleepData:
            return .missingSleepData
        case .noHeartData:
            return .missingHeartMetrics
        case .notEnoughBaseline:
            return .insufficientBaselineHistory
        case .syncFailed:
            return .syncFailed
        case .staleData:
            return .staleLocalCache
        case .remoteSyncDisabled:
            return .remoteSyncOptedOut
        case .unknown:
            return .unknown
        }
    }

    private static func requiresHealthPermission(_ context: HealthIntelligenceUIContext) -> Bool {
        if let snapshot = context.snapshot,
           snapshot.nextBestAction.reason == .connectHealth,
           !snapshot.nextBestAction.id.isEmpty {
            return true
        }

        if context.isAppleHealthConnected {
            return false
        }

        if context.availability?.hasAnyReadableSignal == true {
            return false
        }

        if context.snapshot == nil {
            return true
        }

        let recovery = context.snapshot?.recovery ?? .unknown
        let workout = context.snapshot?.workout
        let activity = context.snapshot?.activity ?? .empty

        let hasWorkout = workout?.hasWorkout == true
        let hasActivity = activity.steps != nil
            || activity.activeEnergyKcal != nil
            || activity.exerciseMinutes != nil

        return recovery.status == .unknown && !hasWorkout && !hasActivity
    }

    private static func hasPartialHealthPermission(_ context: HealthIntelligenceUIContext) -> Bool {
        guard !requiresHealthPermission(context) else { return false }
        guard let availability = context.availability else { return false }

        let connected = context.isAppleHealthConnected || availability.hasAnyReadableSignal
        guard connected else { return false }

        if availability.hasAnyReadableSignal, !availability.hasTrainingReadAccess {
            return true
        }

        if availability.hasAnyReadableSignal, !availability.permissionStatus.allRequiredSignalsAvailable {
            return true
        }

        if availability.permissionStatus.anyRequiredSignalDenied, availability.hasAnyReadableSignal {
            return true
        }

        return false
    }

    private static func isStale(_ context: HealthIntelligenceUIContext) -> Bool {
        guard context.cachedDayCount > 0 else { return false }
        guard context.isAppleHealthConnected || context.availability?.hasAnyReadableSignal == true else {
            return false
        }
        guard let lastSync = context.lastSuccessfulLocalSyncAt else { return false }
        return context.now.timeIntervalSince(lastSync) > context.staleAfter
    }

    private static func hasInsufficientBaseline(_ context: HealthIntelligenceUIContext) -> Bool {
        guard !requiresHealthPermission(context) else { return false }

        let connected = context.isAppleHealthConnected || context.availability?.hasAnyReadableSignal == true
        guard connected else { return false }

        if context.cachedDayCount >= HealthIntelligenceUIStatePolicy.minimumBaselineDays {
            return false
        }

        if let baseline = context.baseline {
            let missingCore: Set<HealthBaselineSignal> = [.steps, .sleep, .workoutLoad]
            if missingCore.isSubset(of: baseline.missingSignals), baseline.availableSignals.isEmpty {
                return true
            }
        }

        return context.cachedDayCount == 0 && !hasRenderableInsight(context)
    }

    private static func hasNoWorkoutHistory(_ context: HealthIntelligenceUIContext) -> Bool {
        guard !requiresHealthPermission(context) else { return false }
        guard context.cachedDayCount > 0 else { return false }
        guard context.baseline != nil || context.snapshot != nil else { return false }

        let workoutDays = context.baseline?.workoutDays28d ?? 0
        let hasTodayWorkout = context.snapshot?.workout?.hasWorkout == true
        let hasWorkoutPermission = context.availability?.permissionStatus.access(for: .workout).isReadable == true

        return hasWorkoutPermission && workoutDays == 0 && !hasTodayWorkout
    }

    private static func hasMissingSleepData(_ context: HealthIntelligenceUIContext) -> Bool {
        guard !requiresHealthPermission(context) else { return false }
        guard hasRenderableInsight(context) else { return false }

        let sleepPermitted = context.availability?.permissionStatus.access(for: .sleepAnalysis).isReadable == true
        guard sleepPermitted else { return false }

        let recoveryMissingSleep = context.snapshot?.recovery.missingSignals.contains(.sleep) == true
        let baselineMissingSleep = context.baseline?.missingSignals.contains(.sleep) == true

        return recoveryMissingSleep && baselineMissingSleep
    }

    private static func hasMissingHeartData(_ context: HealthIntelligenceUIContext) -> Bool {
        guard !requiresHealthPermission(context) else { return false }
        guard hasRenderableInsight(context) else { return false }

        let heartSignals: [HealthSignalKind] = [.restingHeartRate, .heartRateVariabilitySDNN]
        let hasHeartPermission = heartSignals.contains {
            context.availability?.permissionStatus.access(for: $0).isReadable == true
        }
        guard hasHeartPermission else { return false }

        let recovery = context.snapshot?.recovery
        let missingHeart = recovery?.missingSignals.contains(.restingHeartRate) == true
            || recovery?.missingSignals.contains(.hrv) == true
        let baselineMissingHeart = context.baseline?.missingSignals.contains(.restingHeartRate) == true
            || context.baseline?.missingSignals.contains(.hrv) == true

        return missingHeart && baselineMissingHeart
    }

    private static func isRemoteSyncDisabled(_ context: HealthIntelligenceUIContext) -> Bool {
        guard context.isRemoteSyncCapabilityEnabled else { return false }
        guard context.remoteSyncConsentDecision == .optedOut else { return false }
        guard !requiresHealthPermission(context) else { return false }
        return context.cachedDayCount == 0 && !hasRenderableInsight(context)
    }

    private static func hasRenderableInsight(_ context: HealthIntelligenceUIContext) -> Bool {
        guard let snapshot = context.snapshot else { return false }

        if snapshot.workout?.hasWorkout == true {
            return true
        }

        let activity = snapshot.activity
        if activity.steps != nil || activity.activeEnergyKcal != nil || activity.exerciseMinutes != nil {
            return true
        }

        if snapshot.recovery.status != .unknown || snapshot.recovery.score != nil {
            return true
        }

        return false
    }
}

struct HealthIntelligenceUIStateMessage: Equatable, Sendable {
    let title: String
    let message: String
    let reassurance: String?
    let primaryActionTitle: String?
    let secondaryActionTitle: String?
    let primaryAction: HealthIntelligenceUIAction
    let secondaryAction: HealthIntelligenceUIAction
}

extension HealthIntelligenceUIState {

    static func resolve(from context: HealthIntelligenceUIContext) -> HealthIntelligenceUIState {
        HealthIntelligenceUIStateMapper.resolve(context)
    }
}

extension HealthIntelligenceUIContext {

    static func from(
        presentationContext: HealthIntelligencePresentationContext,
        baseline: HealthBaselineContext? = nil,
        lastSuccessfulLocalSyncAt: Date? = nil,
        isRemoteSyncCapabilityEnabled: Bool = false,
        isRemoteSyncUserEnabled: Bool = false,
        remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined,
        surface: HealthIntelligenceSurface = .today,
        now: Date = Date()
    ) -> HealthIntelligenceUIContext {
        HealthIntelligenceUIContext(
            isLoading: presentationContext.isLoading,
            explicitErrorMessage: presentationContext.explicitErrorMessage,
            syncPhase: presentationContext.syncPhase,
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            isRemoteSyncUserEnabled: isRemoteSyncUserEnabled,
            remoteSyncConsentDecision: remoteSyncConsentDecision,
            availability: presentationContext.availability,
            snapshot: presentationContext.snapshot,
            baseline: baseline,
            isAppleHealthConnected: presentationContext.isAppleHealthConnected,
            cachedDayCount: presentationContext.cachedDayCount,
            surface: surface,
            now: now
        )
    }
}
