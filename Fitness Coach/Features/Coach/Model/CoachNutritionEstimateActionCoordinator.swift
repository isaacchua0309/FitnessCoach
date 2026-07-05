//
//  CoachNutritionEstimateActionCoordinator.swift
//  Fitness Coach
//
//  Forma — Nutrition estimate card suggested-action handling.
//

import Foundation

@MainActor
final class CoachNutritionEstimateActionCoordinator {

    private let pendingConfirmationCoordinator: CoachPendingConfirmationCoordinator
    private let sendFlowCoordinator: CoachSendFlowCoordinator
    private let launchChromeCoordinator: CoachLaunchChromeCoordinator
    private let inputCoordinator: CoachInputCoordinator
    private var logAnalytics: (CoachAnalyticsEvent, CoachAnalyticsProperties) -> Void = { _, _ in }
    private var lastActionTapAt: Date?

    init(
        pendingConfirmationCoordinator: CoachPendingConfirmationCoordinator,
        sendFlowCoordinator: CoachSendFlowCoordinator,
        launchChromeCoordinator: CoachLaunchChromeCoordinator,
        inputCoordinator: CoachInputCoordinator
    ) {
        self.pendingConfirmationCoordinator = pendingConfirmationCoordinator
        self.sendFlowCoordinator = sendFlowCoordinator
        self.launchChromeCoordinator = launchChromeCoordinator
        self.inputCoordinator = inputCoordinator
    }

    func configure(logAnalytics: @escaping (CoachAnalyticsEvent, CoachAnalyticsProperties) -> Void) {
        self.logAnalytics = logAnalytics
    }

    func handle(
        _ action: NutritionSuggestedAction,
        send: (String) async -> Void
    ) async {
        if let lastTap = lastActionTapAt, Date().timeIntervalSince(lastTap) < 0.6 {
            return
        }
        lastActionTapAt = Date()

        logAnalytics(
            .nutritionEstimateActionTapped,
            CoachAnalyticsProperties(actionType: action.type.rawValue)
        )

        switch action.type {
        case .logMeal:
            guard let mealDraft = NutritionSuggestedActionHandler.mealDraft(from: action) else { return }
            let sanitized = FoodLogDraftNutritionCompleter.sanitize(mealDraft, hintText: mealDraft.displayName)
            let result = CoachPendingConfirmationPresenter.presentFoodPending(
                originalText: "Log \(sanitized.displayName)",
                assistantMessage: nil,
                mealDraft: sanitized,
                confidence: .medium
            )
            pendingConfirmationCoordinator.beginNutritionEstimateLogPending()
            sendFlowCoordinator.applyActionResult(result)

        case .estimateAnother:
            launchChromeCoordinator.requestComposerFocus()
            inputCoordinator.clearText()

        case .addCommonSide, .addDrink, .compareAlternative, .healthierAlternative, .askFollowUp:
            guard let query = NutritionSuggestedActionHandler.followUpQuery(for: action) else { return }
            await send(query)
        }
    }
}
