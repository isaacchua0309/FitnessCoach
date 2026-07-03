//
//  HealthStableIdentifier.swift
//  Fitness Coach
//
//  Forma — Deterministic identifiers for deduplicated Health Intelligence records.
//

import CryptoKit
import Foundation

enum HealthStableIdentifier {

    static func workoutID(
        sourceName: String?,
        startDate: Date,
        endDate: Date,
        durationMinutes: Int,
        category: FormaWorkoutCategory
    ) -> UUID {
        let key = [
            sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            isoTimestamp(startDate),
            isoTimestamp(endDate),
            String(durationMinutes),
            category.rawValue
        ].joined(separator: "|")

        return uuid(from: key)
    }

    static func sleepID(
        startDate: Date,
        endDate: Date,
        asleepMinutes: Double,
        inBedMinutes: Double?
    ) -> UUID {
        let key = [
            isoTimestamp(startDate),
            isoTimestamp(endDate),
            String(format: "%.2f", asleepMinutes),
            inBedMinutes.map { String(format: "%.2f", $0) } ?? ""
        ].joined(separator: "|")

        return uuid(from: key)
    }

    static func heartMetricID(
        kind: HealthHeartMetricKind,
        date: Date,
        value: Double
    ) -> UUID {
        let key = [
            kind.rawValue,
            isoTimestamp(date),
            String(format: "%.3f", value)
        ].joined(separator: "|")

        return uuid(from: key)
    }

    static func bodyMassID(
        date: Date,
        valueKg: Double
    ) -> UUID {
        let key = [
            isoTimestamp(date),
            String(format: "%.3f", valueKg)
        ].joined(separator: "|")

        return uuid(from: key)
    }

    // MARK: - Private

    private static func isoTimestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func uuid(from string: String) -> UUID {
        let digest = SHA256.hash(data: Data(string.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }
}
