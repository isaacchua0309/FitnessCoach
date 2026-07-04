//
//  FoodCorrectionMemoryStore.swift
//  Fitness Coach
//
//  Forma — UID-scoped local store for Coach food correction memory.
//

import Foundation

protocol FoodCorrectionMemoryStoring: Sendable {
    func record(_ entry: FoodCorrectionMemoryEntry) async throws
    func recentEntries(limit: Int) async throws -> [FoodCorrectionMemoryEntry]
    func markUsed(entryIDs: [UUID], at date: Date) async throws
    func deleteAll() async throws
}

enum FoodCorrectionMemoryStoreError: Error, Equatable {
    case notAuthenticated
}

@MainActor
final class FileFoodCorrectionMemoryStore: FoodCorrectionMemoryStoring {

    private let userIdProvider: () -> String?
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cache: [String: [FoodCorrectionMemoryEntry]] = [:]

    init(
        userIdProvider: @escaping () -> String?,
        fileManager: FileManager = .default
    ) {
        self.userIdProvider = userIdProvider
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func record(_ entry: FoodCorrectionMemoryEntry) async throws {
        let userId = try requiredUserId()
        var entries = try loadEntries(for: userId)

        if let index = entries.firstIndex(where: { $0.mergeKey == entry.mergeKey }) {
            var existing = entries[index]
            existing.useCount += 1
            existing.lastUsedAt = entry.createdAt
            existing.afterCalories = entry.afterCalories ?? existing.afterCalories
            existing.correctedFoodName = entry.correctedFoodName ?? existing.correctedFoodName
            existing.amountHint = entry.amountHint ?? existing.amountHint
            entries[index] = existing
        } else {
            entries.insert(entry, at: 0)
        }

        entries = compact(entries)
        try persist(entries, userId: userId)
    }

    func recentEntries(limit: Int) async throws -> [FoodCorrectionMemoryEntry] {
        let userId = try requiredUserId()
        let entries = try loadEntries(for: userId)
        return Array(
            entries
                .sorted { lhs, rhs in
                    let lhsDate = lhs.lastUsedAt ?? lhs.createdAt
                    let rhsDate = rhs.lastUsedAt ?? rhs.createdAt
                    if lhs.useCount == rhs.useCount {
                        return lhsDate > rhsDate
                    }
                    return lhs.useCount > rhs.useCount
                }
                .prefix(max(0, limit))
        )
    }

    func markUsed(entryIDs: [UUID], at date: Date) async throws {
        guard !entryIDs.isEmpty else { return }
        let userId = try requiredUserId()
        var entries = try loadEntries(for: userId)
        let idSet = Set(entryIDs)
        var changed = false

        for index in entries.indices {
            guard idSet.contains(entries[index].id) else { continue }
            entries[index].useCount += 1
            entries[index].lastUsedAt = date
            changed = true
        }

        guard changed else { return }
        try persist(entries, userId: userId)
    }

    func deleteAll() async throws {
        guard let userId = userIdProvider() else { return }
        cache[userId] = []
        let url = fileURL(for: userId)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Private

    private func requiredUserId() throws -> String {
        guard let userId = userIdProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty else {
            throw FoodCorrectionMemoryStoreError.notAuthenticated
        }
        return userId
    }

    private func loadEntries(for userId: String) throws -> [FoodCorrectionMemoryEntry] {
        if let cached = cache[userId] {
            return cached
        }

        let url = fileURL(for: userId)
        guard fileManager.fileExists(atPath: url.path) else {
            cache[userId] = []
            return []
        }

        let data = try Data(contentsOf: url)
        let entries = try decoder.decode([FoodCorrectionMemoryEntry].self, from: data)
        cache[userId] = entries
        return entries
    }

    private func persist(_ entries: [FoodCorrectionMemoryEntry], userId: String) throws {
        let directory = baseDirectoryURL()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(entries)
        try data.write(to: fileURL(for: userId), options: .atomic)
        cache[userId] = entries
    }

    private func compact(_ entries: [FoodCorrectionMemoryEntry]) -> [FoodCorrectionMemoryEntry] {
        Array(entries.prefix(FoodCorrectionMemoryLimits.maxStoredEntries))
    }

    private func baseDirectoryURL() -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return support.appendingPathComponent("FoodCorrectionMemory", isDirectory: true)
    }

    private func fileURL(for userId: String) -> URL {
        let safeName = userId.replacingOccurrences(of: "/", with: "_")
        return baseDirectoryURL().appendingPathComponent("\(safeName).json")
    }

    static func deleteFile(
        for userId: String,
        fileManager: FileManager = .default
    ) -> Bool {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let url = support
            .appendingPathComponent("FoodCorrectionMemory", isDirectory: true)
            .appendingPathComponent("\(userId.replacingOccurrences(of: "/", with: "_")).json")
        guard fileManager.fileExists(atPath: url.path) else { return true }
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }
}

@MainActor
final class InMemoryFoodCorrectionMemoryStore: FoodCorrectionMemoryStoring {

    private var entries: [FoodCorrectionMemoryEntry] = []
    var activeUserId: String?

    func record(_ entry: FoodCorrectionMemoryEntry) async throws {
        if let index = entries.firstIndex(where: { $0.mergeKey == entry.mergeKey }) {
            var existing = entries[index]
            existing.useCount += 1
            existing.lastUsedAt = entry.createdAt
            entries[index] = existing
        } else {
            entries.insert(entry, at: 0)
        }
        entries = Array(entries.prefix(FoodCorrectionMemoryLimits.maxStoredEntries))
    }

    func recentEntries(limit: Int) async throws -> [FoodCorrectionMemoryEntry] {
        Array(entries.prefix(max(0, limit)))
    }

    func markUsed(entryIDs: [UUID], at date: Date) async throws {
        for index in entries.indices where entryIDs.contains(entries[index].id) {
            entries[index].useCount += 1
            entries[index].lastUsedAt = date
        }
    }

    func deleteAll() async throws {
        entries = []
    }
}
