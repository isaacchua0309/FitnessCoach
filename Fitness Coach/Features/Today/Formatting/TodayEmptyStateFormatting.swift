//
//  TodayEmptyStateFormatting.swift
//  Fitness Coach
//
//  Forma — Deterministic empty-state copy and classification for Today.
//

import Foundation

enum TodayMealsEmptyKind: Equatable, Sendable {
    case hasMeals
    case newProfileNoMeals
    case newDayNoMeals
}

enum TodayEmptyStateKind: Equatable, Sendable {
    case missingProfile
    case newProfileNoMeals
    case returningUserNewDayNoMeals
    case loadErrorLocal
    case loadErrorNetwork
    case appleHealthUnavailable
    case noActivityData
    case noRecentWeight
}

struct TodayEmptyStateCopy: Equatable, Sendable {
    var title: String
    var body: String
    var actionTitle: String?
    var accessibilityHint: String?
}

enum TodayEmptyStateFormatting {

    static func mealsEmptyKind(
        mealsEmpty: Bool,
        hasPriorFoodLogs: Bool
    ) -> TodayMealsEmptyKind {
        guard mealsEmpty else { return .hasMeals }
        return hasPriorFoodLogs ? .newDayNoMeals : .newProfileNoMeals
    }

    static func shouldShowWeightReminder(
        weightLoggedToday: Bool,
        hasRecentWeight: Bool
    ) -> Bool {
        !weightLoggedToday && !hasRecentWeight
    }

    static func copy(for kind: TodayEmptyStateKind) -> TodayEmptyStateCopy {
        switch kind {
        case .missingProfile:
            return TodayEmptyStateCopy(
                title: FormaProductCopy.Today.EmptyState.missingProfileTitle,
                body: FormaProductCopy.Today.EmptyState.missingProfileBody,
                actionTitle: FormaProductCopy.Today.EmptyState.missingProfileAction,
                accessibilityHint: FormaProductCopy.Today.EmptyState.missingProfileActionHint
            )
        case .newProfileNoMeals:
            return TodayEmptyStateCopy(
                title: FormaProductCopy.Today.EmptyState.newProfileMealsTitle,
                body: FormaProductCopy.Today.EmptyState.newProfileMealsBody,
                actionTitle: FormaProductCopy.Today.EmptyState.logMealAction,
                accessibilityHint: FormaProductCopy.Today.mealsLogMealAccessibilityHint
            )
        case .returningUserNewDayNoMeals:
            return TodayEmptyStateCopy(
                title: FormaProductCopy.Today.EmptyState.newDayMealsTitle,
                body: FormaProductCopy.Today.EmptyState.newDayMealsBody,
                actionTitle: FormaProductCopy.Today.EmptyState.logMealAction,
                accessibilityHint: FormaProductCopy.Today.mealsLogMealAccessibilityHint
            )
        case .loadErrorLocal:
            return TodayEmptyStateCopy(
                title: FormaProductCopy.Today.EmptyState.loadErrorTitle,
                body: FormaProductCopy.Today.EmptyState.loadErrorLocalBody,
                actionTitle: FormaProductCopy.Common.retry,
                accessibilityHint: nil
            )
        case .loadErrorNetwork:
            return TodayEmptyStateCopy(
                title: FormaProductCopy.Today.EmptyState.loadErrorTitle,
                body: FormaProductCopy.Today.EmptyState.loadErrorNetworkBody,
                actionTitle: FormaProductCopy.Common.retry,
                accessibilityHint: nil
            )
        case .appleHealthUnavailable:
            return TodayEmptyStateCopy(
                title: FormaProductCopy.Today.EmptyState.appleHealthTitle,
                body: FormaProductCopy.Today.EmptyState.appleHealthBody,
                actionTitle: FormaProductCopy.Training.Integration.connectAppleHealth,
                accessibilityHint: FormaProductCopy.Today.nextActionTrainingInsightsHint
            )
        case .noActivityData:
            return TodayEmptyStateCopy(
                title: FormaProductCopy.Today.EmptyState.noActivityTitle,
                body: FormaProductCopy.Today.EmptyState.noActivityBody,
                actionTitle: nil,
                accessibilityHint: nil
            )
        case .noRecentWeight:
            return TodayEmptyStateCopy(
                title: FormaProductCopy.Today.EmptyState.noRecentWeightTitle,
                body: FormaProductCopy.Today.EmptyState.noRecentWeightBody,
                actionTitle: FormaProductCopy.Today.EmptyState.logWeightAction,
                accessibilityHint: FormaProductCopy.EmptyState.WeightTrend.actionAccessibilityHint
            )
        }
    }

    static func mealsEmptyCopy(for kind: TodayMealsEmptyKind) -> TodayEmptyStateCopy {
        switch kind {
        case .hasMeals:
            return TodayEmptyStateCopy(title: "", body: "", actionTitle: nil, accessibilityHint: nil)
        case .newProfileNoMeals:
            return copy(for: .newProfileNoMeals)
        case .newDayNoMeals:
            return copy(for: .returningUserNewDayNoMeals)
        }
    }

    static func missionStatusLine(
        mealsEmptyKind: TodayMealsEmptyKind,
        calorieSummary: CalorieSummary,
        proteinProgress: MacroProgress
    ) -> String {
        switch mealsEmptyKind {
        case .newProfileNoMeals:
            return FormaProductCopy.Today.EmptyState.newProfileMissionStatus
        case .newDayNoMeals:
            return FormaProductCopy.Today.EmptyState.newDayMissionStatus
        case .hasMeals:
            break
        }

        if calorieSummary.isOverTarget {
            return FormaProductCopy.Today.Mission.statusOverTarget
        }
        if proteinProgress.progress < TodayFocusBuilder.proteinOnTrackThreshold {
            return FormaProductCopy.Today.Mission.statusProteinGap
        }
        if TodayMissionHeroFormatter.isNearTarget(calorieSummary) {
            return FormaProductCopy.Today.Mission.statusNearTarget
        }
        return FormaProductCopy.Today.Mission.statusOnTrack
    }

    static func missionShowsLogCTA(mealsEmptyKind: TodayMealsEmptyKind) -> Bool {
        mealsEmptyKind != .hasMeals
    }
}

enum TodayLoadErrorFormatting {

    static func message(for error: Error, isRefresh: Bool) -> String {
        if error is URLError {
            return isRefresh
                ? FormaProductCopy.Today.EmptyState.refreshErrorNetworkBody
                : FormaProductCopy.Today.EmptyState.loadErrorNetworkBody
        }
        return isRefresh
            ? FormaProductCopy.Today.EmptyState.refreshErrorLocalBody
            : FormaProductCopy.Today.EmptyState.loadErrorLocalBody
    }

    static func kind(for error: Error) -> TodayEmptyStateKind {
        error is URLError ? .loadErrorNetwork : .loadErrorLocal
    }
}
