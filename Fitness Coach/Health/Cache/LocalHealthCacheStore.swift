//
//  LocalHealthCacheStore.swift
//  Fitness Coach
//
//  Forma — File-backed local cache for normalized health data with in-memory L1.
//

import Foundation

final class LocalHealthCacheStore: HealthCacheStore, @unchecked Sendable {

    private let memory: MemoryHealthCacheStore
    private let fileManager: FileManager
    private let userProvider: any HealthCacheUserProviding
    private let rootDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSRecursiveLock()

    private var activeUserID: String?
    private var loadedDayKeys = Set<String>()
    private var aggregateIndexesLoaded = false
    private var batchWriteDepth = 0
    private var deferredAggregateFlush = false

    init(
        userProvider: any HealthCacheUserProviding = StaticHealthCacheUserProvider(userID: nil),
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.memory = MemoryHealthCacheStore()
        self.userProvider = userProvider
        self.fileManager = fileManager

        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.rootDirectory = appSupport
                .appendingPathComponent("Forma", isDirectory: true)
                .appendingPathComponent("HealthCache", isDirectory: true)
        }

        self.encoder = encoder
        self.decoder = decoder
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        bootstrapStorageIfNeeded()
    }

    // MARK: - Day bundles

    func entry(for date: Date, calendar: Calendar = .current) -> HealthCacheEntry? {
        ensureUserStorage()

        if let cached = memory.entry(for: date, calendar: calendar) {
            return cached
        }

        let day = calendar.startOfDay(for: date)
        guard let file = loadDayFile(for: day, calendar: calendar) else {
            return nil
        }

        let entry = HealthCacheEntry(
            date: day,
            bundle: file.bundle,
            cachedAt: file.cachedAt
        )
        memory.store(entry, calendar: calendar)
        markDayLoaded(day, calendar: calendar)
        return entry
    }

    func store(_ entry: HealthCacheEntry, calendar: Calendar = .current) {
        ensureUserStorage()
        memory.store(entry, calendar: calendar)

        let day = calendar.startOfDay(for: entry.date)
        let file = HealthCachedDayFile(
            date: day,
            cachedAt: entry.cachedAt,
            bundle: entry.bundle
        )

        lock.lock()
        writeDayFile(file, calendar: calendar)
        if batchWriteDepth > 0 {
            upsertAggregateIndexes(from: entry.bundle, calendar: calendar, persistToDisk: false)
            deferredAggregateFlush = true
        } else {
            upsertAggregateIndexes(from: entry.bundle, calendar: calendar, persistToDisk: true)
        }
        touchMetadata()
        let shouldPrune = batchWriteDepth == 0
        lock.unlock()

        if shouldPrune {
            pruneOldEntries(keepingLastDays: HealthCachePolicy.retentionDays, calendar: calendar)
        }
    }

    func beginBatchWrite() {
        lock.lock()
        batchWriteDepth += 1
        lock.unlock()
    }

    func endBatchWrite(calendar: Calendar) {
        lock.lock()
        batchWriteDepth = max(0, batchWriteDepth - 1)
        let shouldFlush = batchWriteDepth == 0 && deferredAggregateFlush
        if batchWriteDepth == 0 {
            deferredAggregateFlush = false
        }
        lock.unlock()

        if shouldFlush {
            flushDeferredAggregateIndexes(calendar: calendar)
        }
    }

    // MARK: - Typed record access

    func dailyMetrics(for date: Date, calendar: Calendar = .current) -> DailyHealthMetrics? {
        entry(for: date, calendar: calendar)?.bundle.dailyMetrics
    }

    func workouts(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [WorkoutRecord] {
        ensureAggregateIndexesLoaded(calendar: calendar)
        return memory.workouts(from: startDate, to: endDate, calendar: calendar)
    }

    func sleepRecords(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [SleepRecord] {
        ensureAggregateIndexesLoaded(calendar: calendar)
        return memory.sleepRecords(from: startDate, to: endDate, calendar: calendar)
    }

    func heartMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [HeartMetricRecord] {
        ensureAggregateIndexesLoaded(calendar: calendar)
        return memory.heartMetrics(from: startDate, to: endDate, calendar: calendar)
    }

    func bodyMassRecords(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [BodyMassRecord] {
        ensureAggregateIndexesLoaded(calendar: calendar)
        return memory.bodyMassRecords(from: startDate, to: endDate, calendar: calendar)
    }

    func upsertWorkouts(_ workouts: [WorkoutRecord], calendar: Calendar = .current) {
        guard !workouts.isEmpty else { return }
        ensureUserStorage()
        ensureAggregateIndexesLoaded(calendar: calendar)
        memory.upsertWorkouts(workouts, calendar: calendar)

        lock.lock()
        persistWorkoutIndex(calendar: calendar)
        touchAggregateIndex(.workouts)
        lock.unlock()
    }

    func upsertSleepRecords(_ records: [SleepRecord], calendar: Calendar = .current) {
        guard !records.isEmpty else { return }
        ensureUserStorage()
        ensureAggregateIndexesLoaded(calendar: calendar)
        memory.upsertSleepRecords(records, calendar: calendar)

        lock.lock()
        persistSleepIndex(calendar: calendar)
        touchAggregateIndex(.sleep)
        lock.unlock()
    }

    func upsertHeartMetrics(_ metrics: [HeartMetricRecord], calendar: Calendar = .current) {
        guard !metrics.isEmpty else { return }
        ensureUserStorage()
        ensureAggregateIndexesLoaded(calendar: calendar)
        memory.upsertHeartMetrics(metrics, calendar: calendar)

        lock.lock()
        persistHeartIndex(calendar: calendar)
        touchAggregateIndex(.heart)
        lock.unlock()
    }

    func upsertBodyMassRecords(_ records: [BodyMassRecord], calendar: Calendar = .current) {
        guard !records.isEmpty else { return }
        ensureUserStorage()
        ensureAggregateIndexesLoaded(calendar: calendar)
        memory.upsertBodyMassRecords(records, calendar: calendar)

        lock.lock()
        persistBodyMassIndex(calendar: calendar)
        touchAggregateIndex(.bodyMass)
        lock.unlock()
    }

    // MARK: - Intelligence placeholders

    func recoverySummary(for date: Date, calendar: Calendar = .current) -> RecoverySummary? {
        ensureUserStorage()
        if let summary = memory.recoverySummary(for: date, calendar: calendar) {
            return summary
        }

        let day = calendar.startOfDay(for: date)
        let url = recoveryURL(for: day, calendar: calendar)
        guard let data = try? Data(contentsOf: url),
              let file = try? decoder.decode(HealthCacheRecoveryFile.self, from: data) else {
            return nil
        }

        memory.storeRecoverySummary(file.summary, for: day, calendar: calendar)
        return file.summary
    }

    func storeRecoverySummary(
        _ summary: RecoverySummary,
        for date: Date,
        calendar: Calendar = .current
    ) {
        ensureUserStorage()
        let day = calendar.startOfDay(for: date)
        memory.storeRecoverySummary(summary, for: day, calendar: calendar)

        let file = HealthCacheRecoveryFile(date: day, cachedAt: Date(), summary: summary)
        let url = recoveryURL(for: day, calendar: calendar)

        lock.lock()
        write(file, to: url)
        touchMetadata()
        lock.unlock()
    }

    func intelligenceSnapshot(for date: Date, calendar: Calendar = .current) -> HealthIntelligenceSnapshot? {
        ensureUserStorage()
        if let snapshot = memory.intelligenceSnapshot(for: date, calendar: calendar) {
            return snapshot
        }

        let day = calendar.startOfDay(for: date)
        let url = snapshotURL(for: day, calendar: calendar)
        guard let data = try? Data(contentsOf: url),
              let file = try? decoder.decode(HealthCacheSnapshotFile.self, from: data) else {
            return nil
        }

        memory.storeIntelligenceSnapshot(file.snapshot, for: day, calendar: calendar)
        return file.snapshot
    }

    func storeIntelligenceSnapshot(
        _ snapshot: HealthIntelligenceSnapshot,
        for date: Date,
        calendar: Calendar = .current
    ) {
        ensureUserStorage()
        let day = calendar.startOfDay(for: date)
        memory.storeIntelligenceSnapshot(snapshot, for: day, calendar: calendar)

        let file = HealthCacheSnapshotFile(date: day, cachedAt: Date(), snapshot: snapshot)
        let url = snapshotURL(for: day, calendar: calendar)

        lock.lock()
        write(file, to: url)
        touchMetadata()
        lock.unlock()
    }

    func weeklyReview(for weekStartDate: Date, calendar: Calendar = .current) -> WeeklyHealthReview? {
        ensureUserStorage()
        if let review = memory.weeklyReview(for: weekStartDate, calendar: calendar) {
            return review
        }

        guard let weekStart = WeeklyReviewWeekPolicy.normalizedWeekStart(weekStartDate, calendar: calendar) else {
            return nil
        }

        let url = weeklyReviewURL(for: weekStart, calendar: calendar)
        guard let data = try? Data(contentsOf: url),
              let file = try? decoder.decode(HealthCacheWeeklyReviewFile.self, from: data) else {
            return nil
        }

        memory.storeWeeklyReview(file.review, calendar: calendar)
        return file.review
    }

    func storeWeeklyReview(_ review: WeeklyHealthReview, calendar: Calendar = .current) {
        ensureUserStorage()
        memory.storeWeeklyReview(review, calendar: calendar)

        guard let weekStart = WeeklyReviewWeekPolicy.normalizedWeekStart(review.weekStartDate, calendar: calendar) else {
            return
        }

        let file = HealthCacheWeeklyReviewFile(
            weekStartDate: weekStart,
            cachedAt: Date(),
            review: review
        )
        let url = weeklyReviewURL(for: weekStart, calendar: calendar)

        lock.lock()
        write(file, to: url)
        touchMetadata()
        lock.unlock()
    }

    // MARK: - Freshness & maintenance

    func dayCoverageIsFresh(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let days = Self.days(from: startDate, to: endDate, calendar: calendar)
        for day in days {
            guard let entry = entry(for: day, calendar: calendar),
                  isFresh(cachedAt: entry.cachedAt, for: day, calendar: calendar) else {
                return false
            }
        }
        return !days.isEmpty
    }

    func invalidate(through date: Date, calendar: Calendar = .current) {
        memory.invalidate(through: date, calendar: calendar)
    }

    func pruneOldEntries(keepingLastDays: Int, calendar: Calendar = .current) {
        guard let cutoff = HealthCachePolicy.pruneCutoffDate(
            keepingLastDays: keepingLastDays,
            calendar: calendar
        ) else {
            return
        }

        memory.pruneOldEntries(keepingLastDays: keepingLastDays, calendar: calendar)

        lock.lock()
        defer { lock.unlock() }

        guard let userDirectory = userDirectoryURL(createIfNeeded: false) else {
            return
        }

        pruneFiles(in: daysDirectoryURL(for: userDirectory), cutoff: cutoff, calendar: calendar)
        pruneFiles(in: recoveryDirectoryURL(for: userDirectory), cutoff: cutoff, calendar: calendar)
        pruneFiles(in: snapshotsDirectoryURL(for: userDirectory), cutoff: cutoff, calendar: calendar)
        pruneFiles(in: weeklyReviewsDirectoryURL(for: userDirectory), cutoff: cutoff, calendar: calendar)

        var metadata = loadMetadata() ?? .initial(userID: resolvedUserID())
        metadata.lastPrunedAt = Date()
        saveMetadata(metadata)
    }

    func indexUpdatedAt(for aggregate: HealthCacheAggregateKind) -> Date? {
        ensureUserStorage()
        if let memoryDate = memory.indexUpdatedAt(for: aggregate) {
            return memoryDate
        }
        let metadata = loadMetadata()
        switch aggregate {
        case .workouts:
            return metadata?.workoutsIndexUpdatedAt
        case .sleep:
            return metadata?.sleepIndexUpdatedAt
        case .heart:
            return metadata?.heartIndexUpdatedAt
        case .bodyMass:
            return metadata?.bodyMassIndexUpdatedAt
        }
    }

    func cachedDayCount(calendar: Calendar = .current) -> Int {
        ensureUserStorage()
        if memory.cachedDayCount(calendar: calendar) > 0 {
            return memory.cachedDayCount(calendar: calendar)
        }

        guard let userDirectory = userDirectoryURL(createIfNeeded: false) else {
            return 0
        }

        let daysDirectory = daysDirectoryURL(for: userDirectory)
        guard let files = try? fileManager.contentsOfDirectory(
            at: daysDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }

        return files.filter { $0.pathExtension == "json" }.count
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        memory.clearAll()
        loadedDayKeys.removeAll()
        aggregateIndexesLoaded = false
        batchWriteDepth = 0
        deferredAggregateFlush = false

        if let userDirectory = userDirectoryURL(createIfNeeded: false) {
            try? fileManager.removeItem(at: userDirectory)
        }

        activeUserID = nil
        bootstrapStorageIfNeeded()
    }

    // MARK: - Storage bootstrap

    private func bootstrapStorageIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let userID = resolvedUserID()
        if activeUserID != userID {
            memory.clearAll()
            loadedDayKeys.removeAll()
            aggregateIndexesLoaded = false
            activeUserID = userID
        }

        guard let userDirectory = userDirectoryURL(createIfNeeded: true) else {
            return
        }

        try? fileManager.createDirectory(at: daysDirectoryURL(for: userDirectory), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: recoveryDirectoryURL(for: userDirectory), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: snapshotsDirectoryURL(for: userDirectory), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: weeklyReviewsDirectoryURL(for: userDirectory), withIntermediateDirectories: true)

        if loadMetadata() == nil {
            saveMetadata(.initial(userID: userID))
        }
    }

    private func ensureUserStorage() {
        lock.lock()
        let current = resolvedUserID()
        let needsBootstrap = activeUserID != current
        lock.unlock()

        if needsBootstrap {
            bootstrapStorageIfNeeded()
        }
    }

    private func ensureAggregateIndexesLoaded(calendar: Calendar) {
        ensureUserStorage()

        lock.lock()
        let alreadyLoaded = aggregateIndexesLoaded
        lock.unlock()
        guard !alreadyLoaded else { return }

        lock.lock()
        defer { lock.unlock() }
        guard !aggregateIndexesLoaded else { return }

        if let workouts: [String: WorkoutRecord] = readCodable(from: workoutIndexURL()) {
            memory.upsertWorkouts(Array(workouts.values), calendar: calendar)
        }
        if let sleep: [String: SleepRecord] = readCodable(from: sleepIndexURL()) {
            memory.upsertSleepRecords(Array(sleep.values), calendar: calendar)
        }
        if let heart: [String: HeartMetricRecord] = readCodable(from: heartIndexURL()) {
            memory.upsertHeartMetrics(Array(heart.values), calendar: calendar)
        }
        if let bodyMass: [String: BodyMassRecord] = readCodable(from: bodyMassIndexURL()) {
            memory.upsertBodyMassRecords(Array(bodyMass.values), calendar: calendar)
        }

        aggregateIndexesLoaded = true
    }

    // MARK: - Disk helpers

    private func resolvedUserID() -> String {
        let trimmed = userProvider.currentUserID()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else {
            return HealthCachePolicy.anonymousUserID
        }
        return trimmed
    }

    private func userDirectoryURL(createIfNeeded: Bool) -> URL? {
        let userID = resolvedUserID()
        let url = rootDirectory.appendingPathComponent(userID, isDirectory: true)
        if createIfNeeded {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private func daysDirectoryURL(for userDirectory: URL) -> URL {
        userDirectory.appendingPathComponent("days", isDirectory: true)
    }

    private func recoveryDirectoryURL(for userDirectory: URL) -> URL {
        userDirectory.appendingPathComponent("recovery", isDirectory: true)
    }

    private func snapshotsDirectoryURL(for userDirectory: URL) -> URL {
        userDirectory.appendingPathComponent("snapshots", isDirectory: true)
    }

    private func weeklyReviewsDirectoryURL(for userDirectory: URL) -> URL {
        userDirectory.appendingPathComponent("weekly-reviews", isDirectory: true)
    }

    private func dayFileURL(for day: Date, calendar: Calendar) -> URL? {
        guard let userDirectory = userDirectoryURL(createIfNeeded: true) else {
            return nil
        }
        let key = dayKey(for: day, calendar: calendar)
        return daysDirectoryURL(for: userDirectory).appendingPathComponent("\(key).json")
    }

    private func recoveryURL(for day: Date, calendar: Calendar) -> URL {
        let userDirectory = userDirectoryURL(createIfNeeded: true)!
        let key = dayKey(for: day, calendar: calendar)
        return recoveryDirectoryURL(for: userDirectory).appendingPathComponent("\(key).json")
    }

    private func snapshotURL(for day: Date, calendar: Calendar) -> URL {
        let userDirectory = userDirectoryURL(createIfNeeded: true)!
        let key = dayKey(for: day, calendar: calendar)
        return snapshotsDirectoryURL(for: userDirectory).appendingPathComponent("\(key).json")
    }

    private func weeklyReviewURL(for weekStart: Date, calendar: Calendar) -> URL {
        let userDirectory = userDirectoryURL(createIfNeeded: true)!
        let key = dayKey(for: weekStart, calendar: calendar)
        return weeklyReviewsDirectoryURL(for: userDirectory).appendingPathComponent("\(key).json")
    }

    private func workoutIndexURL() -> URL {
        userDirectoryURL(createIfNeeded: true)!.appendingPathComponent("workouts.json")
    }

    private func sleepIndexURL() -> URL {
        userDirectoryURL(createIfNeeded: true)!.appendingPathComponent("sleep.json")
    }

    private func heartIndexURL() -> URL {
        userDirectoryURL(createIfNeeded: true)!.appendingPathComponent("heart.json")
    }

    private func bodyMassIndexURL() -> URL {
        userDirectoryURL(createIfNeeded: true)!.appendingPathComponent("body-mass.json")
    }

    private func metadataURL() -> URL {
        userDirectoryURL(createIfNeeded: true)!.appendingPathComponent("metadata.json")
    }

    private func loadDayFile(for day: Date, calendar: Calendar) -> HealthCachedDayFile? {
        guard let url = dayFileURL(for: day, calendar: calendar),
              let data = try? Data(contentsOf: url),
              let file = try? decoder.decode(HealthCachedDayFile.self, from: data),
              file.schemaVersion == HealthCachePolicy.schemaVersion else {
            return nil
        }

        markDayLoaded(day, calendar: calendar)
        return file
    }

    private func writeDayFile(_ file: HealthCachedDayFile, calendar: Calendar) {
        guard let url = dayFileURL(for: file.date, calendar: calendar) else {
            return
        }
        write(file, to: url)
        markDayLoaded(file.date, calendar: calendar)
    }

    private func markDayLoaded(_ day: Date, calendar: Calendar) {
        loadedDayKeys.insert(dayKey(for: day, calendar: calendar))
    }

    private func upsertAggregateIndexes(
        from bundle: HealthNormalizedDayBundle,
        calendar: Calendar,
        persistToDisk: Bool
    ) {
        if !bundle.workouts.isEmpty {
            memory.upsertWorkouts(bundle.workouts, calendar: calendar)
            if persistToDisk {
                persistWorkoutIndex(calendar: calendar)
                touchAggregateIndex(.workouts)
            }
        }
        if !bundle.sleepRecords.isEmpty {
            memory.upsertSleepRecords(bundle.sleepRecords, calendar: calendar)
            if persistToDisk {
                persistSleepIndex(calendar: calendar)
                touchAggregateIndex(.sleep)
            }
        }
        if !bundle.heartMetrics.isEmpty {
            memory.upsertHeartMetrics(bundle.heartMetrics, calendar: calendar)
            if persistToDisk {
                persistHeartIndex(calendar: calendar)
                touchAggregateIndex(.heart)
            }
        }
        if !bundle.bodyMassRecords.isEmpty {
            memory.upsertBodyMassRecords(bundle.bodyMassRecords, calendar: calendar)
            if persistToDisk {
                persistBodyMassIndex(calendar: calendar)
                touchAggregateIndex(.bodyMass)
            }
        }
        aggregateIndexesLoaded = true
    }

    private func flushDeferredAggregateIndexes(calendar: Calendar) {
        lock.lock()
        defer { lock.unlock() }

        persistWorkoutIndex(calendar: calendar)
        persistSleepIndex(calendar: calendar)
        persistHeartIndex(calendar: calendar)
        persistBodyMassIndex(calendar: calendar)
        touchAggregateIndex(.workouts)
        touchAggregateIndex(.sleep)
        touchAggregateIndex(.heart)
        touchAggregateIndex(.bodyMass)
    }

    private func persistWorkoutIndex(calendar: Calendar) {
        let records = dictionaryByID(memory.workouts(
            from: .distantPast,
            to: .distantFuture,
            calendar: calendar
        ))
        write(records, to: workoutIndexURL())
    }

    private func persistSleepIndex(calendar: Calendar) {
        let records = dictionaryByID(memory.sleepRecords(
            from: .distantPast,
            to: .distantFuture,
            calendar: calendar
        ))
        write(records, to: sleepIndexURL())
    }

    private func persistHeartIndex(calendar: Calendar) {
        let records = dictionaryByID(memory.heartMetrics(
            from: .distantPast,
            to: .distantFuture,
            calendar: calendar
        ))
        write(records, to: heartIndexURL())
    }

    private func persistBodyMassIndex(calendar: Calendar) {
        let records = dictionaryByID(memory.bodyMassRecords(
            from: .distantPast,
            to: .distantFuture,
            calendar: calendar
        ))
        write(records, to: bodyMassIndexURL())
    }

    private func dictionaryByID<T: Identifiable>(_ values: [T]) -> [String: T] where T.ID == UUID {
        Dictionary(uniqueKeysWithValues: values.map { ($0.id.uuidString, $0) })
    }

    private func loadMetadata() -> HealthCacheMetadata? {
        readCodable(from: metadataURL())
    }

    private func saveMetadata(_ metadata: HealthCacheMetadata) {
        write(metadata, to: metadataURL())
    }

    private func touchMetadata() {
        var metadata = loadMetadata() ?? .initial(userID: resolvedUserID())
        metadata.lastUpdatedAt = Date()
        saveMetadata(metadata)
    }

    private func touchAggregateIndex(_ aggregate: HealthCacheAggregateKind) {
        let now = Date()
        var metadata = loadMetadata() ?? .initial(userID: resolvedUserID())
        metadata.lastUpdatedAt = now
        switch aggregate {
        case .workouts:
            metadata.workoutsIndexUpdatedAt = now
        case .sleep:
            metadata.sleepIndexUpdatedAt = now
        case .heart:
            metadata.heartIndexUpdatedAt = now
        case .bodyMass:
            metadata.bodyMassIndexUpdatedAt = now
        }
        saveMetadata(metadata)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else {
            return
        }
        let directory = url.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private func readCodable<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }

    private func pruneFiles(in directory: URL, cutoff: Date, calendar: Calendar) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for file in files where file.pathExtension == "json" {
            let key = file.deletingPathExtension().lastPathComponent
            guard let day = dayFromKey(key, calendar: calendar),
                  day < cutoff else {
                continue
            }
            try? fileManager.removeItem(at: file)
            loadedDayKeys.remove(key)
        }
    }

    private func dayKey(for day: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: day))
    }

    private func dayFromKey(_ key: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: key) else {
            return nil
        }
        return calendar.startOfDay(for: date)
    }

    private static func days(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        guard rangeStart <= rangeEnd else { return [] }

        var days: [Date] = []
        var cursor = rangeStart
        while cursor <= rangeEnd {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return days
    }
}
