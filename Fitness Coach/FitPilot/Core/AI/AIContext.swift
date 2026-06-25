//
//  AIContext.swift
//  Fitness Coach
//
//  FitPilot AI — Compact app state sent to the AI boundary.
//
//  Only minimal, summarized state is included to keep cost low and privacy
//  better. Full database history and full chat history are never sent.
//

import Foundation

struct AIContext: Codable, Equatable, Sendable {
    var date: Date
    var timezoneIdentifier: String
    var userProfileSummary: UserProfileSummary?
    var todaySummary: TodayAISummary?
    var commonFoods: [String]
    var recentMessages: [AIMessageContext]

    init(
        date: Date,
        timezoneIdentifier: String,
        userProfileSummary: UserProfileSummary? = nil,
        todaySummary: TodayAISummary? = nil,
        commonFoods: [String] = [],
        recentMessages: [AIMessageContext] = []
    ) {
        self.date = date
        self.timezoneIdentifier = timezoneIdentifier
        self.userProfileSummary = userProfileSummary
        self.todaySummary = todaySummary
        self.commonFoods = commonFoods
        self.recentMessages = recentMessages
    }
}

struct UserProfileSummary: Codable, Equatable, Sendable {
    var age: Int?
    var sex: Sex?
    var heightCm: Double?
    var currentWeightKg: Double?
    var goalWeightKg: Double?
    var activityLevel: ActivityLevel?
    var trainingFrequencyPerWeek: Int?
}

struct TodayAISummary: Codable, Equatable, Sendable {
    var calorieTarget: Int
    var caloriesConsumed: Int
    var caloriesRemaining: Int
    var proteinTarget: Double
    var proteinConsumed: Double
    var carbsTarget: Double
    var carbsConsumed: Double
    var fatTarget: Double
    var fatConsumed: Double
    var waterTargetMl: Int
    var waterConsumedMl: Int
    var weightKg: Double?
    var steps: Int?
    var workoutCaloriesBurned: Int
}

struct AIMessageContext: Codable, Equatable, Sendable {
    var role: ChatMessageRole
    var text: String
}
