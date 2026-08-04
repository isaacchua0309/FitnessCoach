//
//  HealthIntelligencePresentationCharacterizationFixtures.swift
//  Fitness CoachTests
//
//  Canonical Health Intelligence presentation fixtures (A–E) for cross-surface
//  characterization tests. Deterministic snapshot data; stale sync is relative to `now`.
//

import Foundation
@testable import Fitness_Coach

/// Shared canonical HI presentation states used to freeze current builder output before extraction.
enum HealthIntelligencePresentationCharacterizationFixtures {

  enum Fixture: String, CaseIterable, Sendable {
    case fullyReady = "A"
    case healthKitDisconnected = "B"
    case staleData = "C"
    case partialSignals = "D"
    case weeklyReviewUnavailable = "E"
  }

  static var calendar: Calendar { HealthIntelligenceFixtures.calendar }

  static var todayReferenceDay: Date {
    HealthIntelligenceFixtures.day(2026, 7, 3)
  }

  static var planReferenceDay: Date {
    HealthIntelligenceFixtures.day(2026, 7, 8)
  }

  static var journeyReferenceDay: Date { todayReferenceDay }

  static var referenceNow: Date {
    HealthIntelligencePhase1618TestSupport.referenceNow(calendar: calendar)
  }

  static func staleLastSyncAt(from now: Date = Date()) -> Date {
    now.addingTimeInterval(-(HealthIntelligenceUIStatePolicy.defaultStaleInterval + 60))
  }

  // MARK: - Availability

  static var connectedAvailability: HealthDataAvailability {
    HealthIntelligencePipelineFixtures.connectedAvailability(cachedDays: 28)
  }

  static var deniedAvailability: HealthDataAvailability {
    HealthIntelligencePipelineFixtures.unavailableAvailability()
  }

  static var partialStepsOnlyAvailability: HealthDataAvailability {
    HealthIntelligencePipelineFixtures.stepsOnlyAvailability()
  }

  static var completedConnectionRecord: HealthIntegrationConnectionRecord {
    HealthIntegrationConnectionRecord(
      hasCompletedAppleHealthConnectionFlow: true,
      lastHealthPermissionRequestAt: todayReferenceDay,
      lastSuccessfulHealthReadAt: todayReferenceDay,
      lastHealthSyncAttemptAt: todayReferenceDay
    )
  }

  static var sampleNutritionProgress: TodayHealthIntelligenceNutritionProgress {
    TodayHealthIntelligenceNutritionProgress(
      calorieRemaining: 620,
      proteinRemainingGrams: 42,
      waterRemainingMl: 800,
      hasCalorieTarget: true,
      hasProteinTarget: true,
      hasWaterTarget: true
    )
  }

  // MARK: - Snapshots

  static func fullyReadyWorkoutSnapshot(on day: Date = todayReferenceDay) -> HealthIntelligenceSnapshot {
    HealthIntelligenceSnapshot(
      date: day,
      recovery: RecoverySummary(
        score: 74,
        status: .moderate,
        title: "Moderate recovery",
        explanation: "Recovery is acceptable after recent training.",
        recommendedTraining: "You can train, but avoid stacking intensity tonight.",
        recommendedNutrition: "Prioritize protein and hydration after your workout.",
        confidence: .moderate,
        contributingFactors: [],
        missingSignals: []
      ),
      workout: WorkoutSummary(
        hasWorkout: true,
        primaryWorkoutType: .strength,
        title: "Strength training",
        workoutCount: 1,
        totalDurationMinutes: 50,
        totalActiveCalories: 320,
        intensity: .moderate,
        demand: .high,
        latestWorkoutStart: day,
        latestWorkoutEnd: day,
        nutritionAdvice: "Aim for 30–40g protein in your next meal.",
        hydrationAdviceMl: 700,
        explanation: "Strength training added meaningful load today.",
        confidence: .high,
        sourceSummary: "Synced workout."
      ),
      activity: ActivitySummary(steps: 9_120, activeEnergyKcal: 560, exerciseMinutes: 52),
      nutritionAdjustment: AdaptiveNutritionSummary(
        proteinRecommendationGrams: 35,
        suggestedProteinRemaining: 28,
        waterIncreaseMl: 350,
        suggestedWaterRemainingMl: 900,
        calorieAdvice: "Keep calories steady and prioritize protein after training.",
        shouldChangeTarget: false,
        suggestedCalorieAdjustment: 0,
        adjustmentReason: "",
        priority: 6,
        confidence: .high,
        missingSignals: []
      ),
      weeklyReview: nil,
      planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
      nextBestAction: NextBestAction(
        id: "log-protein",
        title: "Log protein",
        message: "You still have meaningful protein left after today's workout.",
        ctaTitle: "Log meal",
        destination: .logMeal,
        priority: 2,
        reason: .postWorkoutRecovery,
        createdAt: day,
        expiresAt: nil
      )
    )
  }

  static func disconnectedSnapshot(on day: Date = todayReferenceDay) -> HealthIntelligenceSnapshot {
    HealthIntelligenceSnapshot(
      date: day,
      recovery: .unknown,
      workout: nil,
      activity: .empty,
      nutritionAdjustment: .none,
      weeklyReview: nil,
      planConfidence: .unknown,
      nextBestAction: NextBestAction(
        id: "connect-health",
        title: "Connect Apple Health",
        message: "Enable Apple Health to unlock recovery and activity insights.",
        ctaTitle: "",
        destination: .none,
        priority: 1,
        reason: .connectHealth,
        createdAt: day,
        expiresAt: nil
      )
    )
  }

  static func partialSignalsSnapshot(on day: Date = todayReferenceDay) -> HealthIntelligenceSnapshot {
    HealthIntelligencePhase1618TestSupport.sparseSnapshot(on: day)
  }

  static func weeklyReview(on day: Date = journeyReferenceDay) -> WeeklyHealthReview {
    let weekStart = calendar.date(byAdding: .day, value: -6, to: day)!
    return WeeklyHealthReview(
      weekStartDate: weekStart,
      weekEndDate: day,
      title: "Solid training week",
      summary: "You logged consistent workouts and kept protein on track most days.",
      stats: WeeklyStats(
        totalWorkouts: 4,
        totalWorkoutMinutes: 210,
        totalActiveCalories: 1_420,
        averageSteps: 8_200,
        totalSteps: 57_400,
        proteinHitDays: 5,
        calorieTargetHitDays: 4,
        waterHitDays: 3,
        averageRecoveryScore: 68,
        lowRecoveryDays: 1,
        weightChangeKg: -0.3,
        loggingConsistencyDays: 6
      ),
      wins: ["4 workouts logged", "Protein on target 5 days"],
      risks: ["Hydration dipped mid-week"],
      nextWeekFocus: ["Front-load water", "Keep one rest day lighter"],
      confidence: .moderate,
      missingSignals: [],
      generatedAt: day
    )
  }

  // MARK: - Plan baselines

  static func strongPlanBaseline(on day: Date = planReferenceDay) -> HealthBaselineContext {
    HealthBaselineContext(
      targetDate: day,
      averageSteps7d: 8_450,
      averageSteps28d: 7_900,
      averageActiveEnergy7d: 420,
      averageActiveEnergy28d: 390,
      averageSleepDuration7d: 426,
      averageSleepDuration28d: 408,
      averageRestingHeartRate28d: 58,
      averageHRV28d: 52,
      averageWorkoutLoad28d: 180,
      workoutDays7d: 4,
      workoutDays28d: 12,
      availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv, .workoutLoad],
      missingSignals: []
    )
  }

  static func sparsePlanBaseline(on day: Date = planReferenceDay) -> HealthBaselineContext {
    HealthBaselineContext(
      targetDate: day,
      averageSteps7d: 5_200,
      averageSteps28d: nil,
      averageActiveEnergy7d: nil,
      averageActiveEnergy28d: nil,
      averageSleepDuration7d: nil,
      averageSleepDuration28d: nil,
      averageRestingHeartRate28d: nil,
      averageHRV28d: nil,
      averageWorkoutLoad28d: nil,
      workoutDays7d: 1,
      workoutDays28d: 2,
      availableSignals: [.steps, .workoutLoad],
      missingSignals: [.sleep, .hrv, .restingHeartRate, .activeEnergy]
    )
  }

  static func connectedPlan() -> UserPlanContext {
    UserPlanContext(
      calorieTarget: 2_200,
      proteinTargetGrams: 165,
      isAppleHealthConnected: true
    )
  }

  static func planRecovery(score: Int = 74, status: RecoveryStatus = .moderate) -> RecoverySummary {
    RecoverySummary(
      score: score,
      status: status,
      title: "Moderate recovery",
      explanation: "Recovery is acceptable after recent training.",
      recommendedTraining: "Train based on how you feel.",
      recommendedNutrition: "Stay on your usual plan.",
      confidence: .moderate,
      contributingFactors: [],
      missingSignals: []
    )
  }

  // MARK: - Journey helpers

  static func journeyRecoveryDays(
    count: Int = 3,
    referenceDay: Date = journeyReferenceDay
  ) -> [JourneyHealthIntelligenceRecoveryDayInput] {
    (0..<count).compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else {
        return nil
      }
      return JourneyHealthIntelligenceRecoveryDayInput(
        date: day,
        recovery: planRecovery(),
        steps: 7_000 + offset * 250
      )
    }
  }

  static func journeyWorkoutRecord(on day: Date = journeyReferenceDay) -> JourneyHealthIntelligenceWorkoutRecordInput {
    JourneyHealthIntelligenceWorkoutRecordInput(
      id: "\(day.timeIntervalSince1970)-strength",
      date: day,
      title: "Strength training",
      durationMinutes: 50,
      activeCalories: 320,
      demand: .high,
      intensity: .moderate
    )
  }

  // MARK: - Surface builders

  static func buildTodaySection(
    for fixture: Fixture,
    now: Date = Date()
  ) -> TodayHealthIntelligenceSectionState? {
    switch fixture {
    case .fullyReady:
      return TodayHealthIntelligencePresentationBuilder.buildSection(
        snapshot: fullyReadyWorkoutSnapshot(),
        nutritionProgress: sampleNutritionProgress,
        isUIEnabled: true,
        availability: connectedAvailability,
        isAppleHealthConnected: true,
        trainingIntegrationState: .connected,
        connectionRecord: completedConnectionRecord,
        cachedDayCount: connectedAvailability.cachedDayCount
      )

    case .healthKitDisconnected:
      return TodayHealthIntelligencePresentationBuilder.buildSection(
        snapshot: disconnectedSnapshot(),
        nutritionProgress: sampleNutritionProgress,
        isUIEnabled: true,
        availability: deniedAvailability,
        isAppleHealthConnected: false,
        cachedDayCount: 0
      )

    case .staleData:
      return TodayHealthIntelligencePresentationBuilder.buildSection(
        snapshot: fullyReadyWorkoutSnapshot(),
        nutritionProgress: sampleNutritionProgress,
        isUIEnabled: true,
        availability: connectedAvailability,
        isAppleHealthConnected: true,
        trainingIntegrationState: .connected,
        connectionRecord: completedConnectionRecord,
        cachedDayCount: 10,
        lastSuccessfulLocalSyncAt: staleLastSyncAt(from: now)
      )

    case .partialSignals:
      return TodayHealthIntelligencePresentationBuilder.buildSection(
        snapshot: partialSignalsSnapshot(),
        nutritionProgress: sampleNutritionProgress,
        isUIEnabled: true,
        availability: partialStepsOnlyAvailability,
        isAppleHealthConnected: true,
        trainingIntegrationState: .connected,
        connectionRecord: completedConnectionRecord,
        cachedDayCount: partialStepsOnlyAvailability.cachedDayCount
      )

    case .weeklyReviewUnavailable:
      return TodayHealthIntelligencePresentationBuilder.buildSection(
        snapshot: fullyReadyWorkoutSnapshot(),
        nutritionProgress: sampleNutritionProgress,
        isUIEnabled: true,
        availability: connectedAvailability,
        isAppleHealthConnected: true,
        trainingIntegrationState: .connected,
        connectionRecord: completedConnectionRecord,
        cachedDayCount: connectedAvailability.cachedDayCount
      )
    }
  }

  static func buildPlanSection(
    for fixture: Fixture,
    now: Date = Date()
  ) -> PlanHealthIntelligenceSectionState {
    switch fixture {
    case .fullyReady:
      return PlanHealthIntelligencePresentationBuilder.buildSection(
        input: PlanHealthIntelligenceBuildInput(
          planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
          baselineContext: strongPlanBaseline(),
          recovery: planRecovery(),
          userPlan: connectedPlan(),
          healthConnection: .connected,
          healthAvailability: connectedAvailability,
          hasNutritionLogging: true,
          hasRecentWeightLog: true,
          cachedDayCount: connectedAvailability.cachedDayCount
        ),
        calendar: calendar
      )

    case .healthKitDisconnected:
      return PlanHealthIntelligencePresentationBuilder.buildSection(
        input: PlanHealthIntelligenceBuildInput(
          planConfidence: .unknown,
          baselineContext: .empty(for: planReferenceDay),
          recovery: .unknown,
          userPlan: UserPlanContext(calorieTarget: 2_100, proteinTargetGrams: 150),
          healthConnection: .disconnected,
          hasNutritionLogging: false,
          hasRecentWeightLog: false
        ),
        calendar: calendar
      )

    case .staleData:
      return PlanHealthIntelligencePresentationBuilder.buildSection(
        input: PlanHealthIntelligenceBuildInput(
          planConfidence: PlanHealthConfidence(score: 0.62, label: "Moderate"),
          baselineContext: strongPlanBaseline(),
          recovery: planRecovery(),
          userPlan: connectedPlan(),
          healthConnection: .connected,
          healthAvailability: connectedAvailability,
          hasNutritionLogging: true,
          hasRecentWeightLog: true,
          cachedDayCount: 10,
          lastSuccessfulLocalSyncAt: staleLastSyncAt(from: now)
        ),
        calendar: calendar
      )

    case .partialSignals:
      return PlanHealthIntelligencePresentationBuilder.buildSection(
        input: PlanHealthIntelligenceBuildInput(
          planConfidence: PlanHealthConfidence(score: 0.52, label: "Moderate"),
          baselineContext: sparsePlanBaseline(),
          recovery: .unknown,
          userPlan: connectedPlan(),
          healthConnection: .partial,
          healthAvailability: partialStepsOnlyAvailability,
          hasNutritionLogging: false,
          hasRecentWeightLog: false,
          cachedDayCount: partialStepsOnlyAvailability.cachedDayCount
        ),
        calendar: calendar
      )

    case .weeklyReviewUnavailable:
      return PlanHealthIntelligencePresentationBuilder.buildSection(
        input: PlanHealthIntelligenceBuildInput(
          planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
          baselineContext: strongPlanBaseline(),
          recovery: planRecovery(),
          userPlan: connectedPlan(),
          healthConnection: .connected,
          healthAvailability: connectedAvailability,
          hasNutritionLogging: true,
          hasRecentWeightLog: true,
          cachedDayCount: connectedAvailability.cachedDayCount
        ),
        calendar: calendar
      )
    }
  }

  static func buildJourneySection(
    for fixture: Fixture,
    now: Date = Date()
  ) -> JourneyHealthIntelligenceSectionState? {
    switch fixture {
    case .fullyReady:
      let review = weeklyReview()
      let base = fullyReadyWorkoutSnapshot()
      let snapshot = HealthIntelligenceSnapshot(
        date: base.date,
        recovery: base.recovery,
        workout: base.workout,
        activity: base.activity,
        nutritionAdjustment: base.nutritionAdjustment,
        weeklyReview: review,
        planConfidence: base.planConfidence,
        nextBestAction: base.nextBestAction
      )
      return JourneyHealthIntelligencePresentationBuilder.buildSection(
        input: JourneyHealthIntelligenceBuildInput(
          todaySnapshot: snapshot,
          recoveryDays: journeyRecoveryDays(),
          workoutRecords: [journeyWorkoutRecord()],
          weeklyReview: review,
          healthConnection: .connected,
          availability: connectedAvailability,
          cachedDayCount: connectedAvailability.cachedDayCount
        ),
        calendar: calendar,
        isUIEnabled: true
      )

    case .healthKitDisconnected:
      return JourneyHealthIntelligencePresentationBuilder.buildSection(
        input: JourneyHealthIntelligenceBuildInput(
          healthConnection: .notConnected
        ),
        calendar: calendar,
        isUIEnabled: true
      )

    case .staleData:
      return JourneyHealthIntelligencePresentationBuilder.buildSection(
        input: JourneyHealthIntelligenceBuildInput(
          todaySnapshot: fullyReadyWorkoutSnapshot(),
          recoveryDays: journeyRecoveryDays(),
          workoutRecords: [journeyWorkoutRecord()],
          healthConnection: .connected,
          availability: connectedAvailability,
          cachedDayCount: 10,
          lastSuccessfulLocalSyncAt: staleLastSyncAt(from: now)
        ),
        calendar: calendar,
        isUIEnabled: true
      )

    case .partialSignals:
      return JourneyHealthIntelligencePresentationBuilder.buildSection(
        input: JourneyHealthIntelligenceBuildInput(
          todaySnapshot: partialSignalsSnapshot(),
          recoveryDays: journeyRecoveryDays(),
          workoutRecords: [],
          healthConnection: .connected,
          availability: partialStepsOnlyAvailability,
          cachedDayCount: partialStepsOnlyAvailability.cachedDayCount
        ),
        calendar: calendar,
        isUIEnabled: true
      )

    case .weeklyReviewUnavailable:
      return JourneyHealthIntelligencePresentationBuilder.buildSection(
        input: JourneyHealthIntelligenceBuildInput(
          todaySnapshot: fullyReadyWorkoutSnapshot(),
          recoveryDays: journeyRecoveryDays(),
          workoutRecords: [journeyWorkoutRecord()],
          weeklyReview: nil,
          healthConnection: .connected,
          availability: connectedAvailability,
          cachedDayCount: connectedAvailability.cachedDayCount
        ),
        calendar: calendar,
        isUIEnabled: true
      )
    }
  }

  // MARK: - UI state (surface metadata)

  static func resolvedUIState(
    for fixture: Fixture,
    surface: HealthIntelligenceSurface,
    now: Date = Date()
  ) -> HealthIntelligenceUIState {
    let snapshot: HealthIntelligenceSnapshot?
    let availability: HealthDataAvailability?
    let isConnected: Bool
    let cachedDayCount: Int
    let lastSync: Date?
    let baseline: HealthBaselineContext?

    switch fixture {
    case .fullyReady:
      snapshot = fullyReadyWorkoutSnapshot()
      availability = connectedAvailability
      isConnected = true
      cachedDayCount = connectedAvailability.cachedDayCount
      lastSync = now
      baseline = nil

    case .healthKitDisconnected:
      snapshot = disconnectedSnapshot()
      availability = deniedAvailability
      isConnected = false
      cachedDayCount = 0
      lastSync = nil
      baseline = nil

    case .staleData:
      snapshot = fullyReadyWorkoutSnapshot()
      availability = connectedAvailability
      isConnected = true
      cachedDayCount = 10
      lastSync = staleLastSyncAt(from: now)
      baseline = nil

    case .partialSignals:
      snapshot = partialSignalsSnapshot()
      availability = partialStepsOnlyAvailability
      isConnected = true
      cachedDayCount = partialStepsOnlyAvailability.cachedDayCount
      lastSync = now
      baseline = nil

    case .weeklyReviewUnavailable:
      snapshot = fullyReadyWorkoutSnapshot()
      availability = connectedAvailability
      isConnected = true
      cachedDayCount = connectedAvailability.cachedDayCount
      lastSync = now
      baseline = nil
    }

    let context = HealthIntelligenceUIContext.from(
      presentationContext: HealthIntelligencePresentationCore.presentationContext(
        snapshot: snapshot,
        isLoading: false,
        availability: availability,
        isAppleHealthConnected: isConnected,
        cachedDayCount: cachedDayCount,
        errorMessage: nil,
        syncPhase: nil,
        trainingIntegrationState: isConnected ? .connected : .notConnected,
        connectionRecord: isConnected ? completedConnectionRecord : .empty,
        baseline: baseline
      ),
      baseline: baseline,
      lastSuccessfulLocalSyncAt: lastSync,
      surface: surface,
      now: now
    )

    return HealthIntelligenceUIStateMapper.resolve(context)
  }

  // MARK: - Section loading classification inputs

  static func sectionLoadingInput(
    for fixture: Fixture,
    surface: HealthIntelligenceSurface,
    isUIEnabled: Bool = true,
    isLoading: Bool = false,
    enginesEnabled: Bool = true,
    weeklyReviewEnabled: Bool = true,
    now: Date = Date()
  ) -> HealthIntelligenceSectionLoadingInput {
    let snapshot: HealthIntelligenceSnapshot?
    let availability: HealthDataAvailability?
    let isConnected: Bool
    let cachedDayCount: Int
    let lastSync: Date?
    let review: WeeklyHealthReview?

    switch fixture {
    case .fullyReady:
      snapshot = fullyReadyWorkoutSnapshot()
      availability = connectedAvailability
      isConnected = true
      cachedDayCount = connectedAvailability.cachedDayCount
      lastSync = now
      review = surface == .journey ? weeklyReview() : nil

    case .healthKitDisconnected:
      snapshot = disconnectedSnapshot()
      availability = deniedAvailability
      isConnected = false
      cachedDayCount = 0
      lastSync = nil
      review = nil

    case .staleData:
      snapshot = fullyReadyWorkoutSnapshot()
      availability = connectedAvailability
      isConnected = true
      cachedDayCount = 10
      lastSync = staleLastSyncAt(from: now)
      review = nil

    case .partialSignals:
      snapshot = partialSignalsSnapshot()
      availability = partialStepsOnlyAvailability
      isConnected = true
      cachedDayCount = partialStepsOnlyAvailability.cachedDayCount
      lastSync = now
      review = nil

    case .weeklyReviewUnavailable:
      snapshot = fullyReadyWorkoutSnapshot()
      availability = connectedAvailability
      isConnected = true
      cachedDayCount = connectedAvailability.cachedDayCount
      lastSync = now
      review = nil
    }

    return HealthIntelligenceSectionLoadingInput(
      isUIEnabled: isUIEnabled,
      isLoading: isLoading,
      enginesEnabled: enginesEnabled,
      weeklyReviewEnabled: weeklyReviewEnabled,
      weeklyReview: review,
      snapshot: snapshot,
      availability: availability,
      isAppleHealthConnected: isConnected,
      cachedDayCount: cachedDayCount,
      lastSuccessfulLocalSyncAt: lastSync,
      surface: surface,
      trainingIntegrationState: isConnected ? .connected : .notConnected,
      connectionRecord: isConnected ? completedConnectionRecord : .empty
    )
  }
}
