//
//  OnboardingPlanBlueprintBuilder.swift
//  Fitness Coach
//
//  Forma — Goal-aware plan blueprint state for onboarding review.
//

import Foundation

struct OnboardingPlanBlueprintProfileSignal: Equatable, Identifiable, Sendable {
    let id: String
    let icon: String
    let headline: String
    let supporting: String
}

struct OnboardingPlanBlueprintState: Equatable, Sendable {
    let goalHero: String
    let goalSubtitle: String
    let goalBadge: String
    let coachInsightTitle: String
    let coachInsightBody: String
    let profileMirrorTitle: String
    let profileSignals: [OnboardingPlanBlueprintProfileSignal]
    let anticipationBullets: [OnboardingFeatureBullet]
    let detailRows: [OnboardingPersonalizationSummaryRecap]
    let accessibilityLabel: String
    let isPersonalized: Bool
}

enum OnboardingPlanBlueprintBuilder {

    static func build(
        from formState: OnboardingFormState,
        referenceDate: Date = Date()
    ) -> OnboardingPlanBlueprintState {
        let copy = FormaProductCopy.Onboarding.Flow.Summary.self
        let detailRows = OnboardingPersonalizationSummaryBuilder.recapCards(
            for: formState,
            referenceDate: referenceDate
        )
        let profileSignals = profileSignals(
            from: formState,
            detailRows: detailRows,
            copy: copy.ProfileMirror.self
        )
        let anticipationBullets = anticipationBullets(copy: copy.Anticipation.self)

        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return fallbackState(
                copy: copy,
                detailRows: detailRows,
                profileSignals: profileSignals,
                anticipationBullets: anticipationBullets
            )
        }

        let direction = OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg
        )
        let journeyLine = journeyLine(
            currentKg: currentKg,
            goalKg: goalKg,
            unitSystem: formState.unitSystem
        )

        switch direction {
        case .cut:
            let hero = OnboardingGoalWeightBounds.changeSummary(
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem
            )
            return makeState(
                copy: copy,
                goalHero: hero,
                goalSubtitle: journeyLine,
                insightTitle: copy.Insight.lossTitle,
                insightBody: copy.Insight.loss,
                detailRows: detailRows,
                profileSignals: profileSignals,
                anticipationBullets: anticipationBullets,
                isPersonalized: true
            )
        case .gain:
            let hero = OnboardingGoalWeightBounds.changeSummary(
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem
            )
            return makeState(
                copy: copy,
                goalHero: hero,
                goalSubtitle: journeyLine,
                insightTitle: copy.Insight.gainTitle,
                insightBody: copy.Insight.gain,
                detailRows: detailRows,
                profileSignals: profileSignals,
                anticipationBullets: anticipationBullets,
                isPersonalized: true
            )
        case .maintain:
            let targetLabel = OnboardingGoalWeightBounds.weightSummary(
                valueKg: goalKg,
                unitSystem: formState.unitSystem
            )
            let hero = FormaProductCopy.Onboarding.Flow.FormaProof.maintainHero(
                targetWeightLabel: targetLabel
            )
            return makeState(
                copy: copy,
                goalHero: hero,
                goalSubtitle: copy.maintainGoalSubtitle,
                insightTitle: copy.Insight.maintainTitle,
                insightBody: copy.Insight.maintain,
                detailRows: detailRows,
                profileSignals: profileSignals,
                anticipationBullets: anticipationBullets,
                isPersonalized: true
            )
        }
    }

    private static func makeState(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Type,
        goalHero: String,
        goalSubtitle: String,
        insightTitle: String,
        insightBody: String,
        detailRows: [OnboardingPersonalizationSummaryRecap],
        profileSignals: [OnboardingPlanBlueprintProfileSignal],
        anticipationBullets: [OnboardingFeatureBullet],
        isPersonalized: Bool
    ) -> OnboardingPlanBlueprintState {
        OnboardingPlanBlueprintState(
            goalHero: goalHero,
            goalSubtitle: goalSubtitle,
            goalBadge: copy.goalSectionTitle,
            coachInsightTitle: insightTitle,
            coachInsightBody: insightBody,
            profileMirrorTitle: copy.ProfileMirror.title,
            profileSignals: profileSignals,
            anticipationBullets: anticipationBullets,
            detailRows: detailRows,
            accessibilityLabel: accessibilityLabel(
                screenTitle: copy.title,
                goalHero: goalHero,
                insightTitle: insightTitle,
                insightBody: insightBody,
                profileSignals: profileSignals
            ),
            isPersonalized: isPersonalized
        )
    }

    private static func fallbackState(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Type,
        detailRows: [OnboardingPersonalizationSummaryRecap],
        profileSignals: [OnboardingPlanBlueprintProfileSignal],
        anticipationBullets: [OnboardingFeatureBullet]
    ) -> OnboardingPlanBlueprintState {
        OnboardingPlanBlueprintState(
            goalHero: copy.goalFallbackHero,
            goalSubtitle: copy.goalFallbackSubtitle,
            goalBadge: copy.goalSectionTitle,
            coachInsightTitle: copy.Insight.fallbackTitle,
            coachInsightBody: copy.Insight.fallback,
            profileMirrorTitle: copy.ProfileMirror.title,
            profileSignals: profileSignals,
            anticipationBullets: anticipationBullets,
            detailRows: detailRows,
            accessibilityLabel: accessibilityLabel(
                screenTitle: copy.title,
                goalHero: copy.goalFallbackHero,
                insightTitle: copy.Insight.fallbackTitle,
                insightBody: copy.Insight.fallback,
                profileSignals: profileSignals
            ),
            isPersonalized: false
        )
    }

    private static func profileSignals(
        from formState: OnboardingFormState,
        detailRows: [OnboardingPersonalizationSummaryRecap],
        copy: FormaProductCopy.Onboarding.Flow.Summary.ProfileMirror.Type
    ) -> [OnboardingPlanBlueprintProfileSignal] {
        let rowValue: (String) -> String? = { id in
            guard let value = detailRows.first(where: { $0.id == id })?.value,
                  value != "—" else {
                return nil
            }
            return value
        }

        var signals: [OnboardingPlanBlueprintProfileSignal] = []

        if let height = rowValue("height"), let weight = rowValue("currentWeight") {
            signals.append(
                OnboardingPlanBlueprintProfileSignal(
                    id: "measurements",
                    icon: "ruler",
                    headline: "\(height) · \(weight)",
                    supporting: copy.measurements
                )
            )
        }

        if let age = rowValue("age"), let sex = rowValue("sex") {
            signals.append(
                OnboardingPlanBlueprintProfileSignal(
                    id: "profile",
                    icon: "person.fill",
                    headline: "\(age) · \(sex)",
                    supporting: copy.profile
                )
            )
        }

        if let activity = rowValue("activity") {
            signals.append(
                OnboardingPlanBlueprintProfileSignal(
                    id: "activity",
                    icon: "figure.walk",
                    headline: activity,
                    supporting: copy.activity
                )
            )
        }

        if let target = rowValue("targetWeight") {
            signals.append(
                OnboardingPlanBlueprintProfileSignal(
                    id: "target",
                    icon: "scope",
                    headline: target,
                    supporting: copy.target
                )
            )
        }

        return signals
    }

    private static func anticipationBullets(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Anticipation.Type
    ) -> [OnboardingFeatureBullet] {
        copy.bullets.map { bullet in
            OnboardingFeatureBullet(
                icon: bullet.icon,
                title: bullet.title,
                subtitle: ""
            )
        }
    }

    private static func journeyLine(
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem
    ) -> String {
        let currentLabel = OnboardingGoalWeightBounds.weightSummary(
            valueKg: currentKg,
            unitSystem: unitSystem
        )
        let goalLabel = OnboardingGoalWeightBounds.weightSummary(
            valueKg: goalKg,
            unitSystem: unitSystem
        )
        return "\(currentLabel) → \(goalLabel)"
    }

    private static func accessibilityLabel(
        screenTitle: String,
        goalHero: String,
        insightTitle: String,
        insightBody: String,
        profileSignals: [OnboardingPlanBlueprintProfileSignal]
    ) -> String {
        let spokenHero = goalHero
            .replacingOccurrences(of: " kg", with: " kilograms")
            .replacingOccurrences(of: " lb", with: " pounds")
        let profileSummary = profileSignals.isEmpty
            ? FormaProductCopy.Onboarding.Flow.Summary.ProfileMirror.accessibilityList
            : profileSignals.map(\.headline).joined(separator: ", ")
        return "\(screenTitle). \(spokenHero). \(insightTitle). \(insightBody) Shaped by \(profileSummary)."
    }
}
