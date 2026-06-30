//
//  PlanNextMilestonePresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Presentation layer for Plan next milestone state.
//

import Foundation

enum PlanNextMilestonePresentationBuilder {

    static func build(from candidate: PlanNextMilestoneSelector.Candidate?) -> PlanNextMilestoneState {
        guard let candidate else {
            return emptyState()
        }

        var state = PlanNextMilestoneState(
            milestoneLabel: candidate.milestoneLabel,
            remainingKg: candidate.remainingKg,
            remainingLabel: candidate.remainingLabel,
            expectedDate: candidate.expectedDate,
            expectedDateLabel: candidate.expectedDateLabel,
            milestoneType: candidate.milestoneType,
            detailCopy: candidate.detailCopy,
            showsEmptyState: false,
            sectionTitle: FormaProductCopy.PlanMissionControl.nextMilestoneSectionTitle,
            headline: candidate.headline,
            showsJourneyCTA: true,
            goToJourneyTitle: FormaProductCopy.PlanMissionControl.goToJourney,
            accessibilitySummary: "",
            kind: candidate.kind
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func emptyState() -> PlanNextMilestoneState {
        let headline = FormaProductCopy.PlanMissionControl.nextMilestoneEmpty
        var state = PlanNextMilestoneState(
            milestoneLabel: nil,
            remainingKg: nil,
            remainingLabel: nil,
            expectedDate: nil,
            expectedDateLabel: nil,
            milestoneType: nil,
            detailCopy: headline,
            showsEmptyState: true,
            sectionTitle: FormaProductCopy.PlanMissionControl.nextMilestoneSectionTitle,
            headline: headline,
            showsJourneyCTA: false,
            goToJourneyTitle: FormaProductCopy.PlanMissionControl.goToJourney,
            accessibilitySummary: "",
            kind: nil
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func accessibilitySummary(for state: PlanNextMilestoneState) -> String {
        var parts = [state.sectionTitle, state.headline]
        if let detailCopy = state.detailCopy, detailCopy != state.headline {
            parts.append(detailCopy)
        }
        if let expectedDateLabel = state.expectedDateLabel {
            parts.append(expectedDateLabel)
        }
        return parts.joined(separator: ". ")
    }
}
