//
//  PlanTrainingIntegrationPresentation.swift
//  Fitness Coach
//
//  Forma — Presentation model for the Apple Health card on Plan.
//

import Foundation

struct PlanTrainingIntegrationPresentation: Equatable, Sendable {
    var sectionTitle: String
    var statusLabel: String
    var showsStatusCheckmark: Bool
    var bodyCopy: String
    var ctaTitle: String?
    var accessibilitySummary: String
}

enum PlanTrainingIntegrationPresentationBuilder {

    static func build(integrationState: TrainingIntegrationState) -> PlanTrainingIntegrationPresentation {
        let statusLabel = TrainingIntegrationCopy.planCardStatusLabel(for: integrationState)
        let bodyCopy = TrainingIntegrationCopy.planCardBodyCopy(for: integrationState)
        let showsCheckmark = TrainingIntegrationCopy.planCardShowsStatusCheckmark(for: integrationState)
        let ctaTitle = TrainingIntegrationCopy.planCardCTATitle(for: integrationState)

        var presentation = PlanTrainingIntegrationPresentation(
            sectionTitle: TrainingIntegrationCopy.planCardSectionTitle,
            statusLabel: statusLabel,
            showsStatusCheckmark: showsCheckmark,
            bodyCopy: bodyCopy,
            ctaTitle: ctaTitle,
            accessibilitySummary: ""
        )
        presentation.accessibilitySummary = accessibilitySummary(for: presentation)
        return presentation
    }

    private static func accessibilitySummary(for presentation: PlanTrainingIntegrationPresentation) -> String {
        var parts = [presentation.sectionTitle, presentation.statusLabel, presentation.bodyCopy]
        if let ctaTitle = presentation.ctaTitle {
            parts.append(ctaTitle)
        }
        return parts.joined(separator: ". ")
    }
}
