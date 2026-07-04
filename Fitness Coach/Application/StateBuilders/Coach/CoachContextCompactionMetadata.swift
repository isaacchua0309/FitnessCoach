//
//  CoachContextCompactionMetadata.swift
//  Fitness Coach
//
//  Debug metadata describing CoachContextPacketV2 timeline/size compaction.
//

import Foundation

struct CoachContextCompactionMetadata: Codable, Equatable, Sendable {

    var originalEventCount: Int
    var exportedEventCount: Int
    var compactedEventCount: Int
    var compactionReason: String?

    init(
        originalEventCount: Int = 0,
        exportedEventCount: Int = 0,
        compactedEventCount: Int = 0,
        compactionReason: String? = nil
    ) {
        self.originalEventCount = originalEventCount
        self.exportedEventCount = exportedEventCount
        self.compactedEventCount = compactedEventCount
        self.compactionReason = compactionReason
    }

    mutating func recordTimelineCompaction(
        originalCount: Int,
        exportedCount: Int,
        reason: String?
    ) {
        originalEventCount = originalCount
        exportedEventCount = exportedCount
        compactedEventCount = max(0, originalCount - exportedCount)
        if let reason, !reason.isEmpty {
            compactionReason = mergedReason(compactionReason, reason)
        }
    }

    mutating func recordSizeCompaction(
        previousExportedCount: Int,
        newExportedCount: Int,
        reason: String
    ) {
        exportedEventCount = newExportedCount
        compactedEventCount = max(compactedEventCount, max(0, previousExportedCount - newExportedCount))
        compactionReason = mergedReason(compactionReason, reason)
    }

    private func mergedReason(_ existing: String?, _ next: String) -> String {
        guard let existing, !existing.isEmpty else { return next }
        if existing.contains(next) { return existing }
        return "\(existing); \(next)"
    }
}
