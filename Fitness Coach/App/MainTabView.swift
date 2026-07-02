//
//  MainTabView.swift
//  Fitness Coach
//
//  FitPilot AI — Main tab shell shown after onboarding or when profile exists.
//

import SwiftUI

private enum AppTab: String, Hashable {
    case today
    case coach
    case journey
    case plan

    /// Legacy tab ids before Phase 6 rename. Maps to Journey / Plan.
    static let legacyTrainingTabID = "training"
    static let legacyJourneyTabID = "progress"
    static let legacyPlanTabID = "profile"

    static func fromPersistedSelection(_ raw: String?) -> AppTab {
        guard let raw else { return .today }
        switch raw {
        case legacyTrainingTabID, legacyJourneyTabID:
            return .journey
        case legacyPlanTabID:
            return .plan
        default:
            return AppTab(rawValue: raw) ?? .today
        }
    }
}

struct MainTabView: View {

    private let container: AppContainer
    private let journeyAnalyticsCoordinator: JourneyAnalyticsCoordinator

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var todayModel: TodayModel
    @StateObject private var coachModel: CoachModel
    @StateObject private var journeyModel: JourneyModel
    @StateObject private var planModel: PlanModel

    @State private var selectedTab: AppTab

    init(container: AppContainer) {
        self.container = container
        self.journeyAnalyticsCoordinator = container.makeJourneyAnalyticsCoordinator()
        _todayModel = StateObject(wrappedValue: container.makeTodayModel())
        _coachModel = StateObject(wrappedValue: container.makeCoachModel())
        _journeyModel = StateObject(wrappedValue: container.makeJourneyModel())
        _planModel = StateObject(wrappedValue: container.makePlanModel())
        _selectedTab = State(initialValue: Self.resolveInitialTab())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                model: todayModel,
                actionCoordinator: container.makeTodayActionCoordinator(),
                healthActivityQuery: container.healthActivityQueryService,
                onOpenCoach: { prefill in
                    coachModel.prepareInput(prefill: prefill)
                    selectedTab = .coach
                },
                onOpenJourney: {
                    selectedTab = .journey
                },
                onOpenPlan: {
                    selectedTab = .plan
                }
            )
            .tabItem {
                Label("Today", systemImage: "house")
            }
            .tag(AppTab.today)

            CoachView(model: coachModel)
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right")
                }
            .tag(AppTab.coach)

            JourneyView(
                model: journeyModel,
                analyticsCoordinator: journeyAnalyticsCoordinator,
                onOpenCoach: { prefill in
                    coachModel.prepareInput(prefill: prefill)
                    selectedTab = .coach
                },
                onOpenPlan: {
                    selectedTab = .plan
                }
            )
                .tabItem {
                    Label("Journey", systemImage: "chart.line.uptrend.xyaxis")
                }
            .tag(AppTab.journey)

            PlanView(
                model: planModel,
                onGoToToday: {
                    selectedTab = .today
                },
                onGoToJourney: {
                    selectedTab = .journey
                }
            )
                .tabItem {
                    Label("Plan", systemImage: "target")
                }
            .tag(AppTab.plan)
        }
        .tint(FormaTokens.Theme.primary)
        .environmentObject(container.refreshCenter)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
        .environmentObject(container.themeStore)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                container.refreshCenter.refreshIfDayChanged()
            }
        }
        .task {
            await bootstrapAfterEntry()
        }
    }

    private func bootstrapAfterEntry() async {
        coachModel.refreshTodayContext()
        await planModel.refresh()
    }

    // MARK: - Tab selection

    private static let selectedTabStorageKey = "forma.mainTab.selectedTab"

    /// Training was removed from the tab bar; open Training Insights from Today, Plan, or Journey.
    private static func resolveInitialTab() -> AppTab {
        let persisted = UserDefaults.standard.string(forKey: selectedTabStorageKey)
        let destination = OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: persisted)
        if persisted == AppTab.legacyTrainingTabID || persisted == AppTab.legacyJourneyTabID {
            UserDefaults.standard.set(AppTab.journey.rawValue, forKey: selectedTabStorageKey)
        } else if persisted == AppTab.legacyPlanTabID {
            UserDefaults.standard.set(AppTab.plan.rawValue, forKey: selectedTabStorageKey)
        }
        return AppTab.fromPersistedSelection(destination.rawValue)
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    MainTabView(container: container)
        .environmentObject(container.authManager)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
        .environmentObject(container.themeStore)
        .formaThemePreview()
}
