//
//  CrossDeviceEndToEndSyncTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 5 two-device cross-device sync end-to-end simulations.
//

import Combine
import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class CrossDeviceEndToEndSyncTests: XCTestCase {

    private let referenceDate = ProfileFixtures.referenceDate

    func testDeviceALogsFoodDeviceBReceivesIt() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        _ = try simulation.deviceA.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Cloud Oats", calories: 420, protein: 18),
            date: simulation.referenceDate
        )
        try await simulation.deviceA.uploadPending()

        _ = try await simulation.deviceB.pullFromCloud()

        let foods = try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate)
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.name, "Cloud Oats")
        XCTAssertEqual(foods.first?.calories, 420)

        let todayModel = try simulation.deviceB.makeTodayModel()
        await todayModel.loadToday()
        guard case .loaded(let dashboard) = todayModel.viewState else {
            return XCTFail("Expected loaded Today on device B")
        }
        XCTAssertEqual(dashboard.meals.entryCount, 1)
        XCTAssertEqual(dashboard.mission.calorieSummary.consumed, 420)
    }

    func testDeviceAEditsFoodDeviceBUpdatesIt() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        let entry = try simulation.deviceA.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Original Meal", calories: 300),
            date: simulation.referenceDate
        )
        try await simulation.deviceA.uploadPending()
        _ = try await simulation.deviceB.pullFromCloud()

        simulation.deviceA.clock.advance(by: 120)
        _ = try simulation.deviceA.actionCenter.editFoodEntry(
            id: entry.id,
            update: FoodEntryUpdate(name: "Edited Meal", calories: 360)
        )
        try await simulation.deviceA.uploadPending()
        _ = try await simulation.deviceB.pullFromCloud()

        let foods = try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate)
        XCTAssertEqual(foods.first?.name, "Edited Meal")
        XCTAssertEqual(foods.first?.calories, 360)
    }

    func testDeviceADeletesFoodDeviceBRemovesIt() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        let entry = try simulation.deviceA.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Delete Me", calories: 250),
            date: simulation.referenceDate
        )
        try await simulation.deviceA.uploadPending()
        _ = try await simulation.deviceB.pullFromCloud()
        XCTAssertEqual(try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate).count, 1)

        try simulation.deviceA.markFoodSynced(id: entry.id)
        simulation.deviceA.clock.advance(by: 120)
        try simulation.deviceA.actionCenter.deleteFoodEntry(id: entry.id)
        try await simulation.deviceA.uploadPending()
        _ = try await simulation.deviceB.pullFromCloud()

        XCTAssertTrue(try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate).isEmpty)

        let todayModel = try simulation.deviceB.makeTodayModel()
        await todayModel.loadToday()
        guard case .loaded(let dashboard) = todayModel.viewState else {
            return XCTFail("Expected loaded Today on device B")
        }
        XCTAssertEqual(dashboard.meals.entryCount, 0)
        XCTAssertEqual(dashboard.mission.calorieSummary.consumed, 0)
    }

    func testDeviceALogsWaterDeviceBTodayUpdates() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        _ = try simulation.deviceA.actionCenter.logWater(amountMl: 475, date: simulation.referenceDate)
        try await simulation.deviceA.uploadPending()
        _ = try await simulation.deviceB.pullFromCloud()

        XCTAssertEqual(
            try simulation.deviceB.waterLogService.getWaterEntries(for: simulation.referenceDate).count,
            1
        )

        let todayModel = try simulation.deviceB.makeTodayModel()
        await todayModel.loadToday()
        guard case .loaded(let dashboard) = todayModel.viewState else {
            return XCTFail("Expected loaded Today on device B")
        }
        XCTAssertEqual(dashboard.macroHydration.waterSummary.consumedMl, 475)
    }

    func testDeviceALogsWeightDeviceBJourneyUpdates() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        _ = try simulation.deviceA.weightLogService.logWeight(81.4, date: simulation.referenceDate)
        try await simulation.deviceA.uploadPending()
        _ = try await simulation.deviceB.pullFromCloud()

        let weights = try simulation.deviceB.weightLogService.getWeightEntries(
            from: simulation.referenceDate,
            to: simulation.referenceDate
        )
        XCTAssertEqual(weights.count, 1)
        XCTAssertEqual(weights.first?.weightKg ?? 0, 81.4, accuracy: 0.01)

        let journeyModel = simulation.deviceB.makeJourneyModel()
        await journeyModel.loadProgress()
        guard case .loaded(let dashboard) = journeyModel.viewState else {
            return XCTFail("Expected loaded Journey on device B")
        }
        XCTAssertEqual(dashboard.baseline.currentWeightKg ?? 0, 81.4, accuracy: 0.01)
    }

    func testDeviceAUpdatesPlanDeviceBPlanTodayJourneyUpdate() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        simulation.deviceA.clock.advance(by: 60)
        _ = try simulation.deviceA.actionCenter.updatePlan(
            UserProfileUpdate(
                goalWeightKg: 58,
                targets: ProfileFixtures.sampleTargets.withCalories(2_150)
            )
        )
        try await simulation.pushProfileToCloud(from: simulation.deviceA)
        _ = try await simulation.deviceB.pullFromCloud()

        let planModel = simulation.deviceB.makePlanModel()
        await planModel.loadProfile()
        guard case .loaded(let plan) = planModel.viewState else {
            return XCTFail("Expected loaded Plan on device B")
        }
        XCTAssertEqual(plan.profile.targets.calorieTarget, 2_150)

        let todayModel = try simulation.deviceB.makeTodayModel()
        await todayModel.loadToday()
        guard case .loaded(let today) = todayModel.viewState else {
            return XCTFail("Expected loaded Today on device B")
        }
        XCTAssertEqual(today.mission.calorieSummary.target, 2_150)

        let journeyModel = simulation.deviceB.makeJourneyModel()
        await journeyModel.loadProgress()
        guard case .loaded(let journey) = journeyModel.viewState else {
            return XCTFail("Expected loaded Journey on device B")
        }
        XCTAssertEqual(journey.baseline.goalWeightKg, 58)
        XCTAssertTrue(journey.hasProfile)
    }

    func testDeviceBPendingLocalEditNotOverwrittenByDeviceAOlderRemoteChange() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        let entry = try simulation.deviceA.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Shared Meal", calories: 300),
            date: simulation.referenceDate
        )
        try await simulation.deviceA.uploadPending()
        _ = try await simulation.deviceB.pullFromCloud()

        _ = try simulation.deviceB.actionCenter.editFoodEntry(
            id: entry.id,
            update: FoodEntryUpdate(name: "Device B Draft", calories: 360)
        )

        _ = try await simulation.deviceB.pullFromCloud()

        let foods = try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate)
        XCTAssertEqual(foods.first?.name, "Device B Draft")
        XCTAssertEqual(foods.first?.calories, 360)
    }

    func testDifferentUIDDoesNotReceiveOtherAccountData() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()
        try await simulation.seedForeignAccountFood()

        _ = try await simulation.deviceB.pullFromCloud()

        XCTAssertTrue(try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate).isEmpty)
        XCTAssertTrue(try simulation.deviceB.store.fetch(FetchDescriptor<FoodEntryEntity>()).isEmpty)
    }

    func testRealtimeHintCausesDeviceBToPullChanges() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        _ = try simulation.deviceA.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Realtime Meal", calories: 390),
            date: simulation.referenceDate
        )
        try await simulation.deviceA.uploadPending()

        var receivedEvent: AccountDataRefreshEvent?
        let cancellable = simulation.deviceB.refreshEventBus.events.sink { receivedEvent = $0 }

        _ = await simulation.deviceB.crossDeviceSyncCoordinator.handleRealtimeHint(uid: simulation.uid)
        try await Task.sleep(nanoseconds: 700_000_000)
        simulation.deviceB.refreshEventBus.flushImmediately()

        XCTAssertEqual(try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate).count, 1)
        XCTAssertEqual(receivedEvent?.uid, simulation.uid)
        XCTAssertTrue(receivedEvent?.domains.contains(.food) == true)
        cancellable.cancel()
    }

    func testOfflineDeviceBRefreshKeepsExistingLocalData() async throws {
        let simulation = try CrossDeviceEndToEndSimulation.make(referenceDate: referenceDate)
        try await simulation.bootstrapProfiles()

        _ = try simulation.deviceA.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Offline Keep", calories: 280),
            date: simulation.referenceDate
        )
        try await simulation.deviceA.uploadPending()
        _ = try await simulation.deviceB.pullFromCloud()

        let before = try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate)
        XCTAssertEqual(before.count, 1)

        simulation.deviceB.networkChecker.isNetworkAvailable = false
        let summary = try await simulation.deviceB.pullFromCloud()
        XCTAssertEqual(summary.status, .offline)

        let after = try simulation.deviceB.foodLogService.getFoodEntries(for: simulation.referenceDate)
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.name, "Offline Keep")
    }
}
