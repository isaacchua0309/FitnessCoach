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
    @Published private(set) var planHealthIntelligenceSectionState: PlanHealthIntelligenceSectionState?
    @Published private(set) var isCrossDeviceRefreshing = false
    @Published var isShowingEditSheet = false
    @Published var isShowingSettingsSheet = false
    @Published var isShowingTargetRegenerationSheet = false
    @Published private(set) var generatedTargetPreview: CalorieTargetResult?
    @Published private(set) var formErrorMessage: String?
    @Published var editFormState: PlanFormState?
    @Published var editPlanInitialStep: PlanEditWizardStep = .goalAndTargetWeight
    @Published private(set) var editBaselineProfile: UserProfile?

    private var settingsBaselineProfile: UserProfile?
    private var crossDeviceRefreshCancellable: AnyCancellable?
    private var debouncedCrossDeviceReloadTask: Task<Void, Never>?
    private var activeRefreshTask: Task<Void, Never>?

    private var loggedSectionImpressions = Set<PlanAnalyticsSectionImpression>()

    private let actionCenter: FitnessActionCenter
    private let userProfileReader: any UserProfileReading
    private let planTargetCalculator: any PlanTargetCalculating
    private let dailyLogReader: any DailyLogReading
    private let weightLogReader: any WeightLogReading
    private let trainingInsightsStore: TrainingInsightsStore
    private let analyticsLogger: any PlanAnalyticsLogging
    private let healthIntelligenceSnapshotProvider: any HealthIntelligenceSnapshotServing
    private let healthBaselineService: any HealthBaselineProviding
    private let healthDataRepository: (any HealthDataRepositorying)?
    private let healthIntelligenceLoadEnabled: () -> Bool
    private let healthIntelligenceUIEnabled: () -> Bool
    private let healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    private let healthSyncPhaseProvider: () -> HealthSyncPhase?
    private let lastSuccessfulLocalSyncAtProvider: () -> Date?
    private let remoteSyncConsentDecisionProvider: () -> HealthSummarySyncConsentDecision
    private let isRemoteSyncCapabilityEnabled: () -> Bool
    private let ownerUIDProvider: () -> String?
    private let accountDataRefreshEventBus: AccountDataRefreshEventBus?
    private let crossDeviceSyncCoordinator: CrossDeviceSyncCoordinating?

    init(
        actionCenter: FitnessActionCenter,
        userProfileReader: any UserProfileReading,
        planTargetCalculator: any PlanTargetCalculating,
        dailyLogReader: any DailyLogReading,
        weightLogReader: any WeightLogReading,
        trainingInsightsStore: TrainingInsightsStore,
        analyticsLogger: (any PlanAnalyticsLogging)? = nil,
        healthBaselineService: any HealthBaselineProviding,
        healthIntelligenceSnapshotProvider: any HealthIntelligenceSnapshotServing = NoOpHealthIntelligenceSnapshotService(),
        healthDataRepository: (any HealthDataRepositorying)? = nil,
        healthIntelligenceLoadEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldPlanModelLoadHealthIntelligence },
        healthIntelligenceUIEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.isUIEnabled },
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        healthSyncPhaseProvider: @escaping () -> HealthSyncPhase? = { nil },
        lastSuccessfulLocalSyncAtProvider: @escaping () -> Date? = { nil },
        remoteSyncConsentDecisionProvider: @escaping () -> HealthSummarySyncConsentDecision = { .notDetermined },
        isRemoteSyncCapabilityEnabled: @escaping () -> Bool = { false },
        ownerUIDProvider: @escaping () -> String? = { nil },
        accountDataRefreshEventBus: AccountDataRefreshEventBus? = nil,
        crossDeviceSyncCoordinator: CrossDeviceSyncCoordinating? = nil
    ) {
        self.actionCenter = actionCenter
        self.userProfileReader = userProfileReader
        self.planTargetCalculator = planTargetCalculator
        self.dailyLogReader = dailyLogReader
        self.weightLogReader = weightLogReader
        self.trainingInsightsStore = trainingInsightsStore
        self.analyticsLogger = analyticsLogger ?? NoOpPlanAnalyticsLogger()
        self.healthBaselineService = healthBaselineService
        self.healthIntelligenceSnapshotProvider = healthIntelligenceSnapshotProvider
        self.healthDataRepository = healthDataRepository
        self.healthIntelligenceLoadEnabled = healthIntelligenceLoadEnabled
        self.healthIntelligenceUIEnabled = healthIntelligenceUIEnabled
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
        self.healthSyncPhaseProvider = healthSyncPhaseProvider
        self.lastSuccessfulLocalSyncAtProvider = lastSuccessfulLocalSyncAtProvider
        self.remoteSyncConsentDecisionProvider = remoteSyncConsentDecisionProvider
        self.isRemoteSyncCapabilityEnabled = isRemoteSyncCapabilityEnabled
        self.ownerUIDProvider = ownerUIDProvider
        self.accountDataRefreshEventBus = accountDataRefreshEventBus
        self.crossDeviceSyncCoordinator = crossDeviceSyncCoordinator
        bindAccountDataRefreshEventsIfNeeded()
    }

    deinit {
        crossDeviceRefreshCancellable?.cancel()
        debouncedCrossDeviceReloadTask?.cancel()
        activeRefreshTask?.cancel()
    }

    // MARK: Cross-device refresh (Phase 5)

    func bindAccountDataRefreshEventsIfNeeded() {
        guard let accountDataRefreshEventBus else { return }
        crossDeviceRefreshCancellable?.cancel()
        crossDeviceRefreshCancellable = accountDataRefreshEventBus.events
            .compactMap { [weak self] event -> AccountDataRefreshEvent? in
                guard let self else { return nil }
                guard PlanCrossDeviceRefreshPolicy.matchesCurrentUID(
                    event: event,
                    ownerUIDProvider: self.ownerUIDProvider
                ) else {
                    return nil
                }
                guard PlanCrossDeviceRefreshPolicy.shouldReload(for: event) else {
                    return nil
                }
                return event
            }
            .sink { [weak self] _ in
                self?.scheduleCrossDeviceReload()
            }
    }

    func performManualCrossDeviceRefresh() async {
        guard CrossDeviceSyncLifecycle.isManualRefreshEnabled,
              let crossDeviceSyncCoordinator,
              let uid = ownerUIDProvider() else {
            return
        }

        isCrossDeviceRefreshing = true
        defer { isCrossDeviceRefreshing = false }

        _ = await crossDeviceSyncCoordinator.manualRefresh(uid: uid)
    }

    private func scheduleCrossDeviceReload() {
        debouncedCrossDeviceReloadTask?.cancel()
        debouncedCrossDeviceReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                for: .milliseconds(PlanCrossDeviceRefreshPolicy.reloadDebounceMilliseconds)
            )
            guard !Task.isCancelled, let self else { return }
            await self.refresh()
        }
    }

    func resetForUserContextChange() {
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        debouncedCrossDeviceReloadTask?.cancel()
        debouncedCrossDeviceReloadTask = nil
        isCrossDeviceRefreshing = false
        planHealthIntelligenceSectionState = nil
        settingsBaselineProfile = nil
        editFormState = nil
        editBaselineProfile = nil
        isShowingEditSheet = false
        isShowingSettingsSheet = false
        viewState = .loading
    }

    // MARK: Loading

    func loadProfile() async {
        viewState = .loading
        planHealthIntelligenceSectionState = nil
        await refresh()
    }

    func refresh() async {
        let wasLoaded = viewState.isLoaded

        activeRefreshTask?.cancel()
        let task = Task { @MainActor in
            do {
                guard let profile = try userProfileReader.getCurrentProfile() else {
                    guard !Task.isCancelled else { return }
                    planHealthIntelligenceSectionState = nil
                    if !wasLoaded {
                        viewState = .empty
                    }
                    return
                }
                let context = try await makePlanDashboardContext(profile: profile)
                async let healthIntelligenceTask = refreshPlanHealthIntelligenceSection(
                    profile: profile,
                    context: context
                )
                guard !Task.isCancelled else { return }
                viewState = .loaded(
                    PlanStateBuilder.dashboardState(profile: profile, context: context)
                )
                loggedSectionImpressions.removeAll()
                syncOpenSheetsAfterCrossDeviceRefresh()
                await healthIntelligenceTask
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                planHealthIntelligenceSectionState = nil
                if !wasLoaded {
                    viewState = .error(FormaProductCopy.Error.loadPlan)
                }
            }
        }

        activeRefreshTask = task
        await task.value
    }

    private func syncOpenSheetsAfterCrossDeviceRefresh() {
        guard case .loaded(let state) = viewState else { return }

        if isShowingSettingsSheet,
           let form = editFormState,
           let baseline = settingsBaselineProfile,
           form == PlanFormState(profile: baseline) {
            editFormState = PlanFormState(profile: state.profile)
            settingsBaselineProfile = state.profile
        }

        if isShowingEditSheet,
           let form = editFormState,
           let baseline = editBaselineProfile,
           form == PlanFormState(profile: baseline) {
            let refreshedForm = PlanFormState(profile: state.profile)
            editFormState = refreshedForm
            editBaselineProfile = state.profile
        }
    }

    // MARK: Health Intelligence

    private func refreshPlanHealthIntelligenceSection(
        profile: UserProfile,
        context: PlanDashboardContext
    ) async {
        guard healthIntelligenceLoadEnabled() else {
            planHealthIntelligenceSectionState = nil
            return
        }

        let uiEnabled = healthIntelligenceUIEnabled()
        let isAppleHealthConnected = trainingInsightsStore.integrationState.isConnected

        guard let healthDataRepository else {
            planHealthIntelligenceSectionState = fallbackPlanHealthIntelligenceSection(
                profile: profile,
                context: context,
                isAppleHealthConnected: isAppleHealthConnected,
                uiEnabled: uiEnabled
            )
            return
        }

        do {
            try Task.checkCancellation()

            let loadResult = await PlanHealthIntelligenceSectionLoader.loadSection(
                profile: profile,
                context: context,
                isAppleHealthConnected: isAppleHealthConnected,
                snapshotProvider: healthIntelligenceSnapshotProvider,
                baselineService: healthBaselineService,
                healthDataRepository: healthDataRepository,
                syncPhase: healthSyncPhaseProvider(),
                lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAtProvider(),
                isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled(),
                remoteSyncConsentDecision: remoteSyncConsentDecisionProvider()
            )

            try Task.checkCancellation()

            planHealthIntelligenceSectionState = uiEnabled ? loadResult.sectionState : nil

            let analyticsContext = HealthIntelligencePresentationContext(
                availability: loadResult.availability,
                snapshot: loadResult.snapshot,
                isAppleHealthConnected: isAppleHealthConnected,
                cachedDayCount: loadResult.availability.cachedDayCount
            )
            let confidenceBucket = loadResult.snapshot.map {
                HealthIntelligenceAnalyticsContextBuilder.confidenceBucket(from: $0.planConfidence)
            } ?? HealthIntelligenceAnalyticsContextBuilder.confidenceBucket(
                from: loadResult.sectionState.confidenceCard.confidenceLabel
            )
            healthIntelligenceAnalyticsCoordinator?.logSnapshotLoaded(
                surface: .plan,
                context: analyticsContext,
                confidenceBucket: confidenceBucket
            )
        } catch is CancellationError {
            return
        } catch {
            planHealthIntelligenceSectionState = fallbackPlanHealthIntelligenceSection(
                profile: profile,
                context: context,
                isAppleHealthConnected: isAppleHealthConnected,
                uiEnabled: uiEnabled
            )

            let analyticsContext = HealthIntelligencePresentationContext(
                explicitErrorMessage: "load_failed",
                isAppleHealthConnected: isAppleHealthConnected
            )
            healthIntelligenceAnalyticsCoordinator?.logSnapshotFailed(
                surface: .plan,
                context: analyticsContext,
                error: error
            )
        }
    }

    private func fallbackPlanHealthIntelligenceSection(
        profile: UserProfile,
        context: PlanDashboardContext,
        isAppleHealthConnected: Bool,
        uiEnabled: Bool
    ) -> PlanHealthIntelligenceSectionState? {
        guard uiEnabled else { return nil }

        let hasNutritionLogging = JourneyLogMetrics.foodLoggedDays(in: context.weekLogs) >= 3
        let hasRecentWeightLog = PlanConfidenceStateBuilder.hasRecentWeightLog(
            in: context.allWeights,
            asOf: context.asOf,
            calendar: context.calendar
        )

        return PlanHealthIntelligencePresentationBuilder.buildSection(
            input: enrichedBuildInput(
                PlanHealthIntelligenceBuildInput(
                    planConfidence: .unknown,
                    baselineContext: .empty(for: context.asOf),
                    recovery: .unknown,
                    userPlan: UserPlanContext.from(
                        profile: profile,
                        isAppleHealthConnected: isAppleHealthConnected
                    ),
                    healthConnection: PlanHealthConnectionState.resolve(
                        isAppleHealthConnected: isAppleHealthConnected,
                        availability: nil
                    ),
                    hasNutritionLogging: hasNutritionLogging,
                    hasRecentWeightLog: hasRecentWeightLog
                )
            ),
            calendar: context.calendar
        )
    }

    private func enrichedBuildInput(
        _ input: PlanHealthIntelligenceBuildInput
    ) -> PlanHealthIntelligenceBuildInput {
        var enriched = input
        enriched.syncPhase = input.syncPhase ?? healthSyncPhaseProvider()
        enriched.lastSuccessfulLocalSyncAt = input.lastSuccessfulLocalSyncAt ?? lastSuccessfulLocalSyncAtProvider()
        enriched.isRemoteSyncCapabilityEnabled = input.isRemoteSyncCapabilityEnabled || isRemoteSyncCapabilityEnabled()
        enriched.remoteSyncConsentDecision = input.remoteSyncConsentDecision == .notDetermined
            ? remoteSyncConsentDecisionProvider()
            : input.remoteSyncConsentDecision
        return enriched
    }

    // MARK: Dashboard context

    private func makePlanDashboardContext(profile: UserProfile) async throws -> PlanDashboardContext {
        let calendar = Calendar.current
        let endDate = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
        let allTimeStart = calendar.date(byAdding: .day, value: -365, to: endDate) ?? endDate

        let weekLogs = try dailyLogReader.getLogs(from: weekStart, to: endDate)
        let allWeights = try weightLogReader.getWeightEntries(from: allTimeStart, to: endDate)

        return PlanDashboardContext(
            profile: profile,
            weekLogs: weekLogs,
            allWeights: allWeights,
            integrationState: trainingInsightsStore.integrationState,
            dataSource: trainingInsightsStore.dataSource,
            asOf: endDate,
            calendar: calendar
        )
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
        logPlanActivityUpdateTapped(
            healthConnected: trainingInsightsStore.integrationState.isConnected
        )
        showEditPlan(
            initialStep: PlanEditWizard.activityLevelStep,
            entryPoint: PlanAdjustPlanEntryPoint.planAssumptions
        )
    }

    func showSettings() {
        guard case .loaded(let state) = viewState else { return }
        formErrorMessage = nil
        editFormState = PlanFormState(profile: state.profile)
        settingsBaselineProfile = state.profile
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
        settingsBaselineProfile = nil
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
            let result = try planTargetCalculator.generateInitialTargets(from: input)
            var draftForm = formState
            draftForm.applyGeneratedTargets(result.targets)
            let draft = try draftForm.makeDraft(targets: result.targets)
            _ = try actionCenter.createProfile(draft)
            await refresh()
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

    func savePlanFromWizard(_ formState: PlanFormState) async throws {
        formErrorMessage = nil
        do {
            var state = formState
            let input = try state.makeCalorieTargetInput()
            let result = try planTargetCalculator.generateInitialTargets(from: input)
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
            dismissSettings()
            await refresh()
            actionCenter.notifyDataChanged()
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
            throw error
        } catch let error as PlanCalculationError {
            formErrorMessage = error.userMessage
            throw error
        } catch ServiceError.invalidInput(let message) {
            formErrorMessage = message
            throw ServiceError.invalidInput(message)
        } catch {
            formErrorMessage = FormaProductCopy.Error.savePlan
            throw error
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
            return try planTargetCalculator.generateInitialTargets(from: input)
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
            generatedTargetPreview = try planTargetCalculator.generateInitialTargets(from: input)
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
        case .strategy: .strategyViewed
        case .status: .statusViewed
        case .confidence: .confidenceViewed
        }

        analyticsLogger.log(
            event,
            properties: makeAnalyticsProperties(healthConnected: healthConnected)
        )
    }

    func logPlanAdjustCTATapped(healthConnected: Bool) {
        analyticsLogger.log(
            .adjustCTATapped,
            properties: makeAnalyticsProperties(healthConnected: healthConnected)
        )
    }

    func logPlanActivityUpdateTapped(healthConnected: Bool) {
        analyticsLogger.log(
            .activityUpdateTapped,
            properties: makeAnalyticsProperties(healthConnected: healthConnected)
        )
    }

    func logPlanTodayTapped(healthConnected: Bool) {
        analyticsLogger.log(
            .todayTapped,
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

    func logPlanCalculationTapped(healthConnected: Bool) {
        analyticsLogger.log(
            .calculationTapped,
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
            properties = PlanAnalyticsProperties(appleHealthConnected: healthConnected)
        }
        configure(&properties)
        return properties
    }
}
