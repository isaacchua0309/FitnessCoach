//
//  JourneyBaselineResolver.swift
//  Fitness Coach
//
//  Forma — Single source of truth for Journey start weight, start date, and chart input.
//

import Foundation

enum JourneyBaselineResolver {

  private static let weightEqualityToleranceKg = 0.05
  private static let profileEditGraceInterval: TimeInterval = 120

  struct Input: Equatable {
    var profile: UserProfile?
    var allWeights: [WeightEntry]
    var maturityLogs: [DailyLog]
    var goalProjection: ProgressProjection?
    var asOf: Date
    var calendar: Calendar
  }

  static func resolve(_ input: Input) -> JourneyBaseline {
    let calendar = input.calendar
    let sortedWeights = validWeightEntries(from: input.allWeights)
    let hasRealWeightEntries = !sortedWeights.isEmpty
    let profile = input.profile
    let profileWeight = profile?.currentWeightKg
    let goalWeight = profile?.goalWeightKg

    let startDate = journeyStartDate(
      profile: profile,
      logs: input.maturityLogs,
      weights: sortedWeights,
      calendar: calendar
    )

    let onboardingWeight = resolveOnboardingBaselineWeightKg(
      profile: profile,
      sortedWeights: sortedWeights,
      startDate: startDate,
      calendar: calendar
    )

    let startResolution = resolveStartWeightKg(
      profileWeight: profileWeight,
      onboardingWeight: onboardingWeight,
      sortedWeights: sortedWeights,
      profile: profile
    )

    let currentWeight = resolveCurrentWeightKg(
      sortedWeights: sortedWeights,
      profileWeight: profileWeight
    )

    let goalDirection = JourneyGoalDirection.resolve(
      startWeightKg: startResolution.weight,
      goalWeightKg: goalWeight
    )

    let totalChangeKg: Double?
    if let start = startResolution.weight, let current = currentWeight {
      totalChangeKg = current - start
    } else {
      totalChangeKg = nil
    }

    let remainingChangeKg: Double?
    if let current = currentWeight, let goal = goalWeight {
      remainingChangeKg = abs(current - goal)
    } else {
      remainingChangeKg = nil
    }

    let progressPercent = goalProgressPercent(
      start: startResolution.weight,
      current: currentWeight,
      goal: goalWeight,
      direction: goalDirection
    )

    let chartPoints = buildChartPoints(
      startDate: startDate,
      asOf: input.asOf,
      onboardingWeight: onboardingWeight,
      startWeightKg: startResolution.weight,
      currentWeightKg: currentWeight,
      sortedWeights: sortedWeights,
      calendar: calendar
    )

    let estimatedCompletionDate = input.goalProjection?.projectedGoalDate
    let estimatedCompletionMonthLabel = estimatedCompletionDate?.formatted(.dateTime.month(.wide).year())

    return JourneyBaseline(
      startWeightKg: startResolution.weight,
      startDate: startDate,
      currentWeightKg: currentWeight,
      goalWeightKg: goalWeight,
      goalDirection: goalDirection,
      totalChangeKg: totalChangeKg,
      remainingChangeKg: remainingChangeKg,
      progressPercent: progressPercent,
      estimatedCompletionDate: estimatedCompletionDate,
      estimatedCompletionMonthLabel: estimatedCompletionMonthLabel,
      hasRealWeightEntries: hasRealWeightEntries,
      usesSyntheticBaselinePoint: startResolution.usesSyntheticBaseline,
      onboardingBaselineWeightKg: onboardingWeight,
      chartPoints: chartPoints,
      showsWeightChart: !chartPoints.isEmpty
    )
  }

  // MARK: - Weight resolution

  private static func validWeightEntries(from entries: [WeightEntry]) -> [WeightEntry] {
    entries
      .filter { $0.weightKg > 0 }
      .sorted { $0.date < $1.date }
  }

  /// Onboarding/profile anchor for synthetic chart lead-in.
  private static func resolveOnboardingBaselineWeightKg(
    profile: UserProfile?,
    sortedWeights: [WeightEntry],
    startDate: Date,
    calendar: Calendar
  ) -> Double? {
    guard let profile, profile.currentWeightKg > 0 else { return nil }

    if sortedWeights.isEmpty {
      return profile.currentWeightKg
    }

    if isProfileWeightTrustedAsOnboardingAnchor(profile: profile, sortedWeights: sortedWeights) {
      return profile.currentWeightKg
    }

    if let entryOnStartDay = weightEntry(on: startDate, in: sortedWeights, calendar: calendar) {
      return entryOnStartDay.weightKg
    }

    return sortedWeights.first?.weightKg
  }

  private static func resolveStartWeightKg(
    profileWeight: Double?,
    onboardingWeight: Double?,
    sortedWeights: [WeightEntry],
    profile: UserProfile?
  ) -> (weight: Double?, usesSyntheticBaseline: Bool) {
    if sortedWeights.isEmpty {
      guard let profileWeight, profileWeight > 0 else {
        return (nil, false)
      }
      return (profileWeight, true)
    }

    let first = sortedWeights.first!
    let last = sortedWeights.last!

    if sortedWeights.count == 1 {
      if let onboardingWeight,
         let profile,
         isProfileWeightTrustedAsOnboardingAnchor(profile: profile, sortedWeights: sortedWeights),
         abs(onboardingWeight - first.weightKg) > weightEqualityToleranceKg {
        return (onboardingWeight, true)
      }
      return (first.weightKg, false)
    }

    // Multiple logs: historical start is earliest log; profile edits must not move the anchor.
    _ = last
    return (first.weightKg, false)
  }

  private static func resolveCurrentWeightKg(
    sortedWeights: [WeightEntry],
    profileWeight: Double?
  ) -> Double? {
    if let latest = sortedWeights.last?.weightKg {
      return latest
    }
    guard let profileWeight, profileWeight > 0 else { return nil }
    return profileWeight
  }

  private static func isProfileWeightTrustedAsOnboardingAnchor(
    profile: UserProfile,
    sortedWeights: [WeightEntry]
  ) -> Bool {
    guard let first = sortedWeights.first else { return true }
    return profile.updatedAt.timeIntervalSince(profile.createdAt) <= profileEditGraceInterval
      || profile.updatedAt <= first.createdAt.addingTimeInterval(profileEditGraceInterval)
  }

  private static func weightEntry(
    on day: Date,
    in entries: [WeightEntry],
    calendar: Calendar
  ) -> WeightEntry? {
    let dayStart = calendar.startOfDay(for: day)
    return entries.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
  }

  // MARK: - Chart points

  static func buildChartPoints(
    startDate: Date,
    asOf: Date,
    onboardingWeight: Double?,
    startWeightKg: Double?,
    currentWeightKg: Double?,
    sortedWeights: [WeightEntry],
    calendar: Calendar
  ) -> [WeightChartPoint] {
    let startDay = calendar.startOfDay(for: startDate)
    let asOfDay = calendar.startOfDay(for: asOf)

    if sortedWeights.isEmpty {
      guard let anchor = onboardingWeight ?? startWeightKg ?? currentWeightKg else {
        return []
      }
      var points: [WeightChartPoint] = [
        WeightChartPoint(
          date: startDay,
          weightKg: anchor,
          isSynthetic: true,
          pointLabel: .onboarding
        )
      ]
      if let current = currentWeightKg,
         abs(current - anchor) > weightEqualityToleranceKg
         || !calendar.isDate(startDay, inSameDayAs: asOfDay) {
        points.append(
          WeightChartPoint(
            date: asOfDay,
            weightKg: current,
            isSynthetic: abs(current - anchor) <= weightEqualityToleranceKg,
            pointLabel: abs(current - anchor) <= weightEqualityToleranceKg ? .onboarding : .started
          )
        )
      } else if !calendar.isDate(startDay, inSameDayAs: asOfDay) {
        points.append(
          WeightChartPoint(
            date: asOfDay,
            weightKg: anchor,
            isSynthetic: true,
            pointLabel: .started
          )
        )
      }
      return deduplicatedChartPoints(points, calendar: calendar)
    }

    var points: [WeightChartPoint] = []
    let syntheticAnchor = onboardingWeight ?? startWeightKg
    let first = sortedWeights.first!

    let needsSyntheticLead: Bool = {
      guard let syntheticAnchor else { return false }
      let sameDay = calendar.isDate(first.date, inSameDayAs: startDay)
      let sameWeight = abs(first.weightKg - syntheticAnchor) <= weightEqualityToleranceKg
      return !sameDay || !sameWeight
    }()

    if needsSyntheticLead, let syntheticAnchor {
      points.append(
        WeightChartPoint(
          date: startDay,
          weightKg: syntheticAnchor,
          isSynthetic: true,
          pointLabel: .onboarding
        )
      )
    }

    for entry in sortedWeights {
      if needsSyntheticLead,
         let syntheticAnchor,
         calendar.isDate(entry.date, inSameDayAs: startDay),
         abs(entry.weightKg - syntheticAnchor) <= weightEqualityToleranceKg {
        continue
      }
      points.append(
        WeightChartPoint(
          id: entry.id,
          date: calendar.startOfDay(for: entry.date),
          weightKg: entry.weightKg,
          isSynthetic: false,
          pointLabel: .logged
        )
      )
    }

    return deduplicatedChartPoints(points.sorted { $0.date < $1.date }, calendar: calendar)
  }

  private static func deduplicatedChartPoints(
    _ points: [WeightChartPoint],
    calendar: Calendar
  ) -> [WeightChartPoint] {
    var seenDays: [Date: WeightChartPoint] = [:]
    for point in points {
      let day = calendar.startOfDay(for: point.date)
      if let existing = seenDays[day] {
        if existing.isSynthetic, !point.isSynthetic {
          seenDays[day] = point
        }
      } else {
        seenDays[day] = point
      }
    }
    return seenDays.values.sorted { $0.date < $1.date }
  }

  /// Filters baseline chart points to the selected analytics window while preserving a synthetic lead-in when needed.
  static func chartPointsInRange(
    _ points: [WeightChartPoint],
    from rangeStart: Date,
    to rangeEnd: Date,
    calendar: Calendar
  ) -> [WeightChartPoint] {
    guard !points.isEmpty else { return [] }

    let rangeStartDay = calendar.startOfDay(for: rangeStart)
    let rangeEndDay = calendar.startOfDay(for: rangeEnd)

    let inRange = points.filter {
      let day = calendar.startOfDay(for: $0.date)
      return day >= rangeStartDay && day <= rangeEndDay
    }

    if inRange.count >= 2 {
      return inRange
    }

    if let syntheticLead = points.first(where: { $0.isSynthetic }),
       let firstInRange = inRange.first,
       calendar.startOfDay(for: syntheticLead.date) < calendar.startOfDay(for: firstInRange.date),
       !inRange.contains(where: { $0.id == syntheticLead.id }) {
      return [syntheticLead] + inRange
    }

    if !inRange.isEmpty {
      return inRange
    }

    return points.filter { calendar.startOfDay(for: $0.date) <= rangeEndDay }
  }

  // MARK: - Dates & progress

  static func journeyStartDate(
    profile: UserProfile?,
    logs: [DailyLog],
    weights: [WeightEntry],
    calendar: Calendar = .current
  ) -> Date {
    let earliestLog = logs.map(\.date).min()
    let earliestWeight = weights.map(\.date).min()
    let candidates = [profile?.createdAt, earliestLog, earliestWeight].compactMap { $0 }
    let raw = candidates.min() ?? Date()
    return calendar.startOfDay(for: raw)
  }

  static func goalProgressPercent(
    start: Double?,
    current: Double?,
    goal: Double?,
    direction: JourneyGoalDirection
  ) -> Double? {
    guard let start, let current, let goal, abs(start - goal) > weightEqualityToleranceKg else {
      return nil
    }

    let total = goal - start
    guard abs(total) > weightEqualityToleranceKg else { return nil }

    let traveled = current - start
    let rawPercent = (traveled / total) * 100
    let nonNegative = max(0, rawPercent)

    switch direction {
    case .lose:
      if current <= goal { return max(nonNegative, 100) }
      return min(nonNegative, 100)
    case .gain:
      if current >= goal { return max(nonNegative, 100) }
      return min(nonNegative, 100)
    case .maintain:
      return min(nonNegative, 100)
    }
  }
}
