//
//  DailyLogRepository.swift
//  Fitness Coach
//
//  Domain protocols for daily log reads.
//

import Foundation

@MainActor
protocol DailyLogReading: AnyObject {
    func getTodayLog() throws -> DailyLog
    func getLog(for date: Date) throws -> DailyLog?
    func getLogs(from startDate: Date, to endDate: Date) throws -> [DailyLog]
    @discardableResult
    func ensureTodayLog() throws -> DailyLog
}

extension DailyLogService: DailyLogReading {}
