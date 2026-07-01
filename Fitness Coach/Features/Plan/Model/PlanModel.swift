//
//  PlanModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for the user's fitness plan strategy.
//

import Combine
import Foundation

@MainActor
final class PlanModel: ObservableObject {

    @Published private(set) var viewState: PlanViewState = .loading
    @Published var isShowingEditSheet = false
    @Published var isShowingSettingsSheet = false
    @Published var isShowingTargetRegenerationSheet = false
    @Published private(set) var generatedTargetPreview: CalorieTargetResult?
    @Published private(set) var formErrorMessage: String?
    @Published var editFormState: PlanFormState?
    @Published var editPlanInitialStep: PlanEditWizardStep = .goalAndTargetWeight
    @Published private(set) var editBaselineProfile: UserProfile?

    private var loggedSectionImpressions = Set<PlanAnalyticsSectionImpression>()

    private let actionCenter: FitnessActionCenter
    private let userProfileService: UserProfileService
    private let targetService: TargetService
    private let dailyLogService: DailyLogService
    private let weightLogService: WeightLogService
    private let trainingInsightsStore: TrainingInsightsStore
    private let workoutReader: HealthKitWorkoutReading
    private let analyticsLogger: any PlanAnalyticsLogging

    init(
        actionCenter: FitnessActionCenter,
        userProfileService: UserProfileService,
        targetService: TargetService,
        dailyLogService: DailyLogService,
        weightLogService: WeightLogService,
        trainingInsightsStore: TrainingInsightsStore,
        workoutReader: HealthKitWorkoutReading? = nil,
        analyticsLogger: (any PlanAnalyticsLogging)? = nil
    ) {
        self.actionCenter = actionCenter
        self.userProfileService = userProfileService
        self.targetService = targetService
        self.dailyLogService = dailyLogService
        self.weightLogService = weightLogService
        self.trainingInsightsStore = trainingInsightsStore
        self.workoutReader = workoutReader ?? MockHealthKitWorkoutReader(workouts: [])
        self.analyticsLogger = analyticsLogger ?? NoOpPlanAnalyticsLogger()
    }

    // MARK: Loading

    func loadProfile() async {
        viewState = .loading
        await refresh()
    }

    func refresh() async {
        do {
            guard let profile = try userProfileService.getCurrentProfile() else {
                viewState = .empty
                return
            }
            let context = try await makePlanDashboardContext(profile: profile)
            viewState = .loaded(
                PlanStateBuilder.dashboardState(profile: profile, context: context)
            )
            loggedSectionImpressions.removeAll()
        } catch {
            viewState = .error(FormaProductCopy.Error.loadPlan)
        }
    }

    // MARK: Dashboard context

    private func makePlanDashboardContext(profile: UserProfile) async throws -> PlanDashboardContext {
        let calendar = Calendar.current
        let endDate = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
        let allTimeStart = calendar.date(byAdding: .day, value: -365, to: endDate) ?? endDate

        let weekLogs = try dailyLogService.getLogs(from: weekStart, to: endDate)
        let allWeights = try weightLogService.getWeightEntries(from: allTimeStart, to: endDate)
        let weekWeights = try weightLogService.getWeightEntries(from: weekStart, to: endDate)

        let integrationState = trainingInsightsStore.integrationState
        let dataSource = trainingInsightsStore.dataSource
        let weekHealthWorkouts = try await fetchHealthWorkouts(from: weekStart, to: endDate)
        let weeklyTraining = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: integrationState,
            dataSource: dataSource,
            weekWorkouts: weekHealthWorkouts,
            asOf: endDate,
            calendar: calendar
        )

        return PlanDashboardContext(
            profile: profile,
            weekLogs: weekLogs,
            weekWeights: weekWeights,
            allWeights: allWeights,
            weeklyTraining: weeklyTraining,
            integrationState: integrationState,
            dataSource: dataSource,
            asOf: endDate,
            calendar: calendar
        )
    }

    private func fetchHealthWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        guard trainingInsightsStore.integrationState.isConnected else {
            return []
        }
        return try await workoutReader.fetchWorkouts(from: startDate, to: endDate)
    }

    // MARK: Sheets

    func showEditPlan(
        initialStep: PlanEditWizardStep = .goalAndTargetWeight,
        entryPoint: String = PlanAdjustPlanEntryPoint.dashboard
    ) {
        guard case .loaded(let state) = viewState else { return }
        let formState = PlanFormState(profile: state.profile)
        let stepIndex = PlanEditWizardFlow.index(of: initialStep, formState: formState) ?? 0
        analyticsLogger.log(
            .adjustStarted,
            properties: makeAnalyticsProperties(healthConnected: trainingInsightsStore.integrationState.isConnected) {
                $0.entryPoint = entryPoint
                $0.initialStep = stepIndex
            }
        )
        formErrorMessage = nil
        editFormState = formState
        editBaselineProfile = state.profile
        editPlanInitialStep = initialStep
        isShowingEditSheet = true
    }

    func showEditPlanActivity() {
        showEditPlan(
            initialStep: PlanEditWizard.activityLevelStep,
            entryPoint: PlanAdjustPlanEntryPoint.activityAssumptions
        )
    }

    func showSettings() {
        guard case .loaded(let state) = viewState else { return }
        formErrorMessage = nil
        editFormState = PlanFormState(profile: state.profile)
        isShowingSettingsSheet = true
    }

    func dismissEditPlan() {
        formErrorMessage = nil
        editFormState = nil
        editBaselineProfile = nil
        editPlanInitialStep = .goalAndTargetWeight
        isShowingEditSheet = false
    }

    func dismissSettings() {
        formErrorMessage = nil
        isShowingSettingsSheet = false
    }

    func dismissTargetRegeneration() {
        generatedTargetPreview = nil
        isShowingTargetRegenerationSheet = false
    }

    func clearError() {
        formErrorMessage = nil
    }

    // MARK: Mutations

    func createDefaultProfile() async {
        do {
            let formState = PlanFormState.defaultDraftValues()
            let input = try formState.makeCalorieTargetInput()
            let result = try targetService.generateInitialTargets(from: input)
            var draftForm = formState
            draftForm.applyGeneratedTargets(result.targets)
            let draft = try draftForm.makeDraft(targets: result.targets)
            _ = try userProfileService.createProfile(draft)
            await refresh()
            actionCenter.notifyDataChanged()
        } catch let error as ProfileFormError {
            viewState = .error(error.message)
        } catch let error as PlanCalculationError {
            viewState = .error(error.userMessage)
        } catch ServiceError.invalidInput(let message) {
            viewState = .error(message)
        } catch {
            viewState = .error(FormaProductCopy.Error.savePlan)
        }
    }

    func savePlanFromWizard(_ formState: PlanFormState) async {
        do {
            var state = formState
            let input = try state.makeCalorieTargetInput()
            let result = try targetService.generateInitialTargets(from: input)
            state.applyGeneratedTargets(result.targets)
            state.syncAggressivenessFromPaceChoice()
            var update = try state.makeUpdate()
            if let baseline = editBaselineProfile {
                update.lastPlanUpdateReason = PlanUpdateReasonResolver.resolve(
                    baseline: baseline,
                    update: update
                )
            }
            _ = try actionCenter.updatePlan(update)
            analyticsLogger.log(
                .editSaved,
                properties: makeAnalyticsProperties(
                    healthConnected: trainingInsightsStore.integrationState.isConnected
                )
            )
            dismissEditPlan()
            dismissSettings()
            await refresh()
            actionCenter.notifyDataChanged()
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
        } catch let error as PlanCalculationError {
            formErrorMessage = error.userMessage
        } catch ServiceError.invalidInput(let message) {
            formErrorMessage = message
        } catch {
            formErrorMessage = FormaProductCopy.Error.savePlan
        }
    }

    func saveSettings(_ formState: PlanFormState) async {
        do {
            let update = try formState.makeUpdate()
            _ = try actionCenter.updatePlan(update)
            await refresh()
            actionCenter.notifyDataChanged()
            formErrorMessage = nil
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
        } catch let error as PlanCalculationError {
            formErrorMessage = error.userMessage
        } catch ServiceError.invalidInput(let message) {
            formErrorMessage = message
        } catch {
            formErrorMessage = FormaProductCopy.Error.saveSettings
        }
    }

    func prepareTargetPreview(from formState: PlanFormState) async throws -> CalorieTargetResult {
        do {
            formErrorMessage = nil
            let input = try formState.makeCalorieTargetInput()
            return try targetService.generateInitialTargets(from: input)
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
            throw error
        } catch let error as PlanCalculationError {
            formErrorMessage = error.userMessage
            throw error
        } catch {
            formErrorMessage = FormaProductCopy.Error.regenerateTargets
            throw error
        }
    }

    func previewRegeneratedTargets(from formState: PlanFormState) async {
        do {
            let input = try formState.makeCalorieTargetInput()
            generatedTargetPreview = try targetService.generateInitialTargets(from: input)
            isShowingTargetRegenerationSheet = true
            formErrorMessage = nil
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
        } catch let error as PlanCalculationError {
            formErrorMessage = error.userMessage
        } catch {
            formErrorMessage = FormaProductCopy.Error.regenerateTargets
        }
    }

    func applyGeneratedTargets() async {
        guard let preview = generatedTargetPreview else { return }
        do {
            _ = try actionCenter.updatePlan(
                UserProfileUpdate(
                    targets: preview.targets,
                    lastPlanUpdateReason: .targetsRegenerated
                )
            )
            analyticsLogger.log(
                .targetsRegenerated,
                properties: makeAnalyticsProperties(
                    healthConnected: trainingInsightsStore.integrationState.isConnected
                )
            )
            dismissTargetRegeneration()
            if isShowingEditSheet, var formState = editFormState {
                formState.applyGeneratedTargets(preview.targets)
                editFormState = formState
            }
            await refresh()
            actionCenter.notifyDataChanged()
        } catch {
            formErrorMessage = FormaProductCopy.Error.regenerateTargets
        }
    }

    // MARK: - Analytics

    func logPlanViewed(healthConnected: Bool) {
        analyticsLogger.log(
            .viewed,
            properties: makeAnalyticsProperties(healthConnected: healthConnected)
        )
    }

    func logSectionImpression(_ section: PlanAnalyticsSectionImpression, healthConnected: Bool) {
        guard case .loaded = viewState else { return }
        guard loggedSectionImpressions.insert(section).inserted else { return }

        let event: PlanAnalyticsEvent = switch section {
        case .goalCard: .goalCardViewed
        case .todayMission: .todayMissionViewed
        case .weekSection: .weekSectionViewed
        case .rationale: .rationaleOpened
        case .activityAssumptions: .activityAssumptionsViewed
        }

        analyticsLogger.log(
            event,
            properties: makeAnalyticsProperties(healthConnected: healthConnected)
        )
    }

    func logPlanTodayTapped(healthConnected: Bool) {
        analyticsLogger.log(
            .todayTapped,
            properties: makeAnalyticsProperties(healthConnected: healthConnected)
        )
    }

    func logPlanJourneyTapped(healthConnected: Bool) {
        analyticsLogger.log(
            .journeyTapped,
            properties: makeAnalyticsProperties(healthConnected: healthConnected)
        )
    }

    func logPlanHealthConnectTapped(
        entryPoint: PlanAnalyticsHealthConnectEntryPoint,
        healthConnected: Bool
    ) {
        analyticsLogger.log(
            .healthConnectTapped,
            properties: makeAnalyticsProperties(healthConnected: healthConnected) {
                $0.entryPoint = entryPoint.rawValue
            }
        )
    }

    func logPlanCalculationDetailsOpened(healthConnected: Bool) {
        analyticsLogger.log(
            .calculationDetailsOpened,
            properties: makeAnalyticsProperties(healthConnected: healthConnected)
        )
    }

    private func makeAnalyticsProperties(
        healthConnected: Bool,
        configure: (inout PlanAnalyticsProperties) -> Void = { _ in }
    ) -> PlanAnalyticsProperties {
        var properties: PlanAnalyticsProperties
        if case .loaded(let state) = viewState {
            properties = PlanAnalyticsProperties.from(
                snapshot: PlanAnalyticsContextBuilder.snapshot(
                    from: state,
                    healthConnected: healthConnected
                )
            )
        } else {
            properties = PlanAnalyticsProperties(healthConnected: healthConnected)
        }
        configure(&properties)
        return properties
    }
}
