//
//  CoachLaunchPresentation.swift
//  Fitness Coach
//
//  Forma — Ephemeral empty-state chrome for a consumed-once Coach launch.
//

import Foundation

struct CoachLaunchPresentation: Equatable, Sendable {
    var headline: String
    var body: String
    var composerPlaceholder: String
    var chips: [CoachLaunchChip]
    var focusesComposer: Bool
}

enum CoachLaunchPresentationBuilder {

    static func presentation(for intent: CoachLaunchIntent) -> CoachLaunchPresentation? {
        switch intent {
        case .normal, .prefill:
            return nil
        case .logMeal(let mealType):
            return CoachLaunchPresentation(
                headline: FormaProductCopy.Coach.Launch.logMealHeadline(mealType: mealType),
                body: FormaProductCopy.Coach.Launch.logMealBody,
                composerPlaceholder: FormaProductCopy.Coach.mealLoggingComposerPlaceholder(mealType: mealType),
                chips: [.takePhoto, .describeMeal, .useVoice],
                focusesComposer: true
            )
        case .analyzePhotoMeal:
            return CoachLaunchPresentation(
                headline: FormaProductCopy.Coach.Launch.analyzePhotoHeadline,
                body: FormaProductCopy.Coach.Launch.analyzePhotoBody,
                composerPlaceholder: FormaProductCopy.Coach.mealLoggingComposerPlaceholder(mealType: nil),
                chips: [.takePhoto, .describeMeal],
                focusesComposer: false
            )
        case .logWater(let amountMl):
            return CoachLaunchPresentation(
                headline: FormaProductCopy.Coach.Launch.logWaterHeadline,
                body: FormaProductCopy.Coach.Launch.logWaterBody,
                composerPlaceholder: FormaProductCopy.Coach.composerPlaceholder,
                chips: [.addWater(amountMl: amountMl)],
                focusesComposer: false
            )
        }
    }

    static func waterLogCommand(amountMl: Int) -> String {
        FormaProductCopy.Coach.Launch.waterLogCommand(amountMl: amountMl)
    }
}
