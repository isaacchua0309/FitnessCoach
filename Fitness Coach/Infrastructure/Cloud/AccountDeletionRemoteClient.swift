//
//  AccountDeletionRemoteClient.swift
//  Fitness Coach
//
//  Forma — HTTP client for remote UID-scoped account data deletion (Phase 6).
//

import Foundation
import OSLog

// MARK: - Protocol

protocol AccountDeletionRemoteDeleting: Sendable {
    func deleteRemoteAccountData(confirmation: String) async throws -> RemoteAccountDeletionResult
}

// MARK: - Result

struct RemoteAccountDeletionResult: Equatable, Sendable {
    let uid: String
    let profileDeleted: Bool
    let dailyLogsDeleted: Int
    let foodEntriesDeleted: Int
    let waterEntriesDeleted: Int
    let weightEntriesDeleted: Int
    let dailyReviewsDeleted: Int
    let syncMetadataDeleted: Bool
    let healthSummariesDeleted: Bool
}

// MARK: - Errors

enum AccountDeletionRemoteError: Error, Equatable, Sendable {
    case unauthenticated
    case reauthenticationRequired
    case offline
    case permissionDenied
    case serverUnavailable
    case timeout
    case unknown(String?)
}

// MARK: - Backend configuration

enum AccountDeletionBackendConfiguration {

    static let environmentVariableName = "FORMA_ACCOUNT_DELETION_BACKEND_URL"

    /// Production Firebase `accountDataDeletion` base URL (no `/v1/account/...` suffix).
    static let productionURLString =
        "https://us-central1-fitness-coach-732fd.cloudfunctions.net/accountDataDeletion"

    private static let logger = Logger(subsystem: "Forma", category: "AccountDeletionBackend")

    static func backendURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let raw = FormaEnvironment.string(
            primary: environmentVariableName,
            environment: environment
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolved = (raw?.isEmpty == false) ? raw! : productionURLString

        guard let url = URL(string: resolved), let host = url.host?.lowercased() else {
            logger.error("Account deletion backend URL is invalid.")
            return nil
        }

        guard AIBackendConfiguration.isLocalhostHost(host) == false else {
            logger.error("Account deletion backend URL rejected (localhost not allowed).")
            return nil
        }

        guard url.scheme == "https" || url.scheme == "http" else {
            logger.error("Account deletion backend URL rejected (unsupported scheme).")
            return nil
        }

        return url
    }
}

// MARK: - HTTP client

final class AccountDeletionRemoteClient: AccountDeletionRemoteDeleting, @unchecked Sendable {

    static let deleteDataEndpoint = "v1/account/delete-data"

    private static let requestTimeout: TimeInterval = 90
    private static let resourceTimeout: TimeInterval = 120

    private let baseURL: URL
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let authTokenProvider: AuthTokenProvider?

    init(
        baseURL: URL,
        urlSession: URLSession? = nil,
        authTokenProvider: AuthTokenProvider? = nil
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession ?? Self.makeSession()
        self.authTokenProvider = authTokenProvider

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func deleteRemoteAccountData(confirmation: String) async throws -> RemoteAccountDeletionResult {
        let trimmedConfirmation = confirmation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedConfirmation.isEmpty else {
            throw AccountDeletionRemoteError.unknown("missing_confirmation")
        }

        AccountDeletionRemoteLogger.requestStarted()

        let url = baseURL.appendingPathComponent(Self.deleteDataEndpoint)
        let endpoint = AccountDeletionDebugEventLogger.safeEndpoint(from: url)
        var hasAuthorizationHeader = false
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let requestBody = DeleteAccountDataRequest(confirmation: trimmedConfirmation)
        let encodedBody: Data
        do {
            encodedBody = try encoder.encode(requestBody)
            urlRequest.httpBody = encodedBody
        } catch {
            AccountDeletionRemoteLogger.requestFailed(category: "encoding")
            throw AccountDeletionRemoteError.unknown("request_encoding_failed")
        }

        if let authTokenProvider {
            do {
                let token = try await authTokenProvider()
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                hasAuthorizationHeader = true
            } catch let error as AuthManagerError {
                let mapped = Self.mapAuthTokenError(error)
                AccountDeletionRemoteLogger.requestFailed(category: Self.errorCategory(mapped))
                AccountDeletionDebugEventLogger.remoteAuthTokenFailure(
                    mappedCategory: AccountDeletionDebugEventLogger.remoteErrorCategoryLabel(mapped)
                )
                throw mapped
            } catch {
                let mapped = Self.mapAuthTokenError(error)
                AccountDeletionRemoteLogger.requestFailed(category: Self.errorCategory(mapped))
                AccountDeletionDebugEventLogger.remoteAuthTokenFailure(
                    mappedCategory: AccountDeletionDebugEventLogger.remoteErrorCategoryLabel(mapped)
                )
                throw mapped
            }
        }

        AccountDeletionDebugEventLogger.remoteRequestPrepared(
            host: endpoint.host,
            path: endpoint.path,
            hasAuthorizationHeader: hasAuthorizationHeader
        )

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: urlRequest)
        } catch {
            let mapped = Self.mapTransportError(error)
            AccountDeletionRemoteLogger.requestFailed(
                category: Self.errorCategory(mapped),
                durationMs: Self.durationMs(since: started)
            )
            AccountDeletionDebugEventLogger.remoteRequestFailed(
                host: endpoint.host,
                path: endpoint.path,
                statusCode: nil,
                mappedCategory: AccountDeletionDebugEventLogger.remoteErrorCategoryLabel(mapped),
                durationMs: Self.durationMs(since: started)
            )
            throw mapped
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if !(200...299).contains(statusCode) {
            let mapped = Self.mapHTTPStatusError(statusCode: statusCode, data: data)
            AccountDeletionRemoteLogger.requestFailed(
                category: Self.errorCategory(mapped),
                statusCode: statusCode,
                durationMs: Self.durationMs(since: started)
            )
            AccountDeletionDebugEventLogger.remoteRequestFailed(
                host: endpoint.host,
                path: endpoint.path,
                statusCode: statusCode,
                mappedCategory: AccountDeletionDebugEventLogger.httpStatusMappedCategory(
                    statusCode: statusCode,
                    mapped: mapped
                ),
                durationMs: Self.durationMs(since: started),
                backendErrorCategory: Self.backendErrorCategory(from: data)
            )
            throw mapped
        }

        let payload: DeleteAccountDataResponse
        do {
            payload = try decoder.decode(DeleteAccountDataResponse.self, from: data)
        } catch {
            AccountDeletionRemoteLogger.requestFailed(
                category: "decode_failure",
                statusCode: statusCode,
                durationMs: Self.durationMs(since: started)
            )
            throw AccountDeletionRemoteError.unknown("response_decode_failed")
        }

        guard payload.ok else {
            AccountDeletionRemoteLogger.requestFailed(
                category: payload.backendErrorCategory ?? "incomplete_deletion",
                statusCode: statusCode,
                durationMs: Self.durationMs(since: started)
            )
            AccountDeletionDebugEventLogger.remoteRequestFailed(
                host: endpoint.host,
                path: endpoint.path,
                statusCode: statusCode,
                mappedCategory: "serverUnavailable",
                durationMs: Self.durationMs(since: started),
                backendErrorCategory: payload.backendErrorCategory
            )
            throw AccountDeletionRemoteError.serverUnavailable
        }

        let result = Self.makeResult(from: payload)
        AccountDeletionRemoteLogger.requestFinished(
            uidSuffix: String(result.uid.suffix(4)),
            result: result,
            durationMs: Self.durationMs(since: started)
        )
        AccountDeletionDebugEventLogger.remoteRequestFinished(
            host: endpoint.host,
            path: endpoint.path,
            statusCode: statusCode,
            mappedCategory: "success",
            durationMs: Self.durationMs(since: started),
            backendErrorCategory: payload.backendErrorCategory
        )
        return result
    }

    // MARK: - Private

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    private static func makeResult(from payload: DeleteAccountDataResponse) -> RemoteAccountDeletionResult {
        let deleted = payload.deleted
        let healthSummariesDeleted =
            deleted.healthDaily > 0
            || deleted.healthWorkouts > 0
            || deleted.healthRecovery > 0
            || deleted.healthWeeklyReviews > 0
            || deleted.healthSyncMetadata

        return RemoteAccountDeletionResult(
            uid: payload.uid,
            profileDeleted: deleted.profile,
            dailyLogsDeleted: deleted.dailyLogs,
            foodEntriesDeleted: deleted.foodEntries,
            waterEntriesDeleted: deleted.waterEntries,
            weightEntriesDeleted: deleted.weightEntries,
            dailyReviewsDeleted: deleted.dailyReviews,
            syncMetadataDeleted: deleted.syncMetadata,
            healthSummariesDeleted: healthSummariesDeleted
        )
    }

    private static func mapAuthTokenError(_ error: Error) -> AccountDeletionRemoteError {
        if let authError = error as? AuthManagerError {
            switch authError {
            case .notSignedIn:
                return .unauthenticated
            case .missingToken:
                return .reauthenticationRequired
            }
        }

        if isRequiresRecentLoginError(error) {
            return .reauthenticationRequired
        }

        return .unauthenticated
    }

    private static func isRequiresRecentLoginError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "FIRAuthErrorDomain",
           nsError.code == 17_014 {
            return true
        }

        let description = error.localizedDescription.lowercased()
        return description.contains("recent login")
            || description.contains("reauthenticate")
            || description.contains("requires recent authentication")
    }

    private static func mapTransportError(_ error: Error) -> AccountDeletionRemoteError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .dataNotAllowed:
                return .offline
            default:
                break
            }
        }

        let description = error.localizedDescription.lowercased()
        if description.contains("timed out") {
            return .timeout
        }
        if description.contains("offline") || description.contains("internet") {
            return .offline
        }

        return .unknown(nil)
    }

    private static func mapHTTPStatusError(
        statusCode: Int,
        data: Data
    ) -> AccountDeletionRemoteError {
        if statusCode == 401 {
            if backendErrorCategory(from: data) == "authentication",
               backendErrorMessage(from: data)?.localizedCaseInsensitiveContains("recent") == true {
                return .reauthenticationRequired
            }
            return .unauthenticated
        }

        if statusCode == 403 {
            return .permissionDenied
        }

        if statusCode == 408 || statusCode == 504 {
            return .timeout
        }

        if statusCode == 503 {
            return .serverUnavailable
        }

        if (500...599).contains(statusCode) {
            return .serverUnavailable
        }

        return .unknown(backendErrorCategory(from: data))
    }

    private static func backendErrorCategory(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let category = object["backendErrorCategory"] as? String else {
            return nil
        }
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func backendErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["error"] as? String else {
            return nil
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func durationMs(since started: Date) -> Int {
        Int(Date().timeIntervalSince(started) * 1_000)
    }

    private static func errorCategory(_ error: AccountDeletionRemoteError) -> String {
        switch error {
        case .unauthenticated:
            return "unauthenticated"
        case .reauthenticationRequired:
            return "reauthentication_required"
        case .offline:
            return "offline"
        case .permissionDenied:
            return "permission_denied"
        case .serverUnavailable:
            return "server_unavailable"
        case .timeout:
            return "timeout"
        case .unknown:
            return "unknown"
        }
    }
}

// MARK: - Request / response DTOs

private struct DeleteAccountDataRequest: Encodable, Equatable {
    let confirmation: String

    private enum CodingKeys: String, CodingKey {
        case confirmation
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(confirmation, forKey: .confirmation)
    }
}

private struct DeleteAccountDataResponse: Decodable {
    let ok: Bool
    let uid: String
    let deleted: DeletedCountsPayload
    let backendErrorCategory: String?

    struct DeletedCountsPayload: Decodable {
        let profile: Bool
        let dailyLogs: Int
        let foodEntries: Int
        let waterEntries: Int
        let weightEntries: Int
        let dailyReviews: Int
        let syncMetadata: Bool
        let healthDaily: Int
        let healthWorkouts: Int
        let healthRecovery: Int
        let healthWeeklyReviews: Int
        let healthSyncMetadata: Bool
    }
}

// MARK: - Logging

private enum AccountDeletionRemoteLogger {

    private static let logger = Logger(subsystem: "Forma", category: "AccountDeletionRemote")

    static func requestStarted() {
        logger.info("Remote account deletion request started")
    }

    static func requestFinished(
        uidSuffix: String,
        result: RemoteAccountDeletionResult,
        durationMs: Int
    ) {
        logger.info(
            """
            Remote account deletion finished uidSuffix=\(uidSuffix, privacy: .public) \
            durationMs=\(durationMs, privacy: .public) \
            dailyLogs=\(result.dailyLogsDeleted, privacy: .public) \
            foodEntries=\(result.foodEntriesDeleted, privacy: .public) \
            waterEntries=\(result.waterEntriesDeleted, privacy: .public) \
            weightEntries=\(result.weightEntriesDeleted, privacy: .public) \
            dailyReviews=\(result.dailyReviewsDeleted, privacy: .public) \
            profileDeleted=\(result.profileDeleted, privacy: .public) \
            syncMetadataDeleted=\(result.syncMetadataDeleted, privacy: .public) \
            healthSummariesDeleted=\(result.healthSummariesDeleted, privacy: .public)
            """
        )
    }

    static func requestFailed(
        category: String,
        statusCode: Int? = nil,
        durationMs: Int? = nil
    ) {
        if let statusCode, let durationMs {
            logger.error(
                """
                Remote account deletion failed category=\(category, privacy: .public) \
                status=\(statusCode, privacy: .public) durationMs=\(durationMs, privacy: .public)
                """
            )
            return
        }

        logger.error("Remote account deletion failed category=\(category, privacy: .public)")
    }
}

// MARK: - In-memory test double

actor InMemoryAccountDeletionRemoteClient: AccountDeletionRemoteDeleting {

    private(set) var callCount = 0
    private(set) var lastConfirmation: String?

    private var configuredResult: RemoteAccountDeletionResult?
    private var configuredError: AccountDeletionRemoteError?

    func configure(
        result: RemoteAccountDeletionResult? = nil,
        error: AccountDeletionRemoteError? = nil
    ) {
        configuredResult = result
        configuredError = error
    }

    func deleteRemoteAccountData(confirmation: String) async throws -> RemoteAccountDeletionResult {
        callCount += 1
        lastConfirmation = confirmation

        if let configuredError {
            throw configuredError
        }

        guard let configuredResult else {
            throw AccountDeletionRemoteError.unknown("not_configured")
        }

        return configuredResult
    }

    func reset() {
        callCount = 0
        lastConfirmation = nil
        configuredResult = nil
        configuredError = nil
    }
}
