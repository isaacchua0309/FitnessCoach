//
//  AccountDeletionRemoteErrorSupport.swift
//  Fitness Coach
//
//  Forma — Maps remote account deletion errors to user copy and failure taxonomy.
//

import Foundation

extension AccountDeletionRemoteError {

    var failureCategory: AccountDeletionFailureCategory {
        switch self {
        case .offline:
            return .offline
        case .unauthorized:
            return .unauthenticated
        case .requiresRecentLogin:
            return .reauthenticationRequired
        case .forbidden:
            return .permissionDenied
        case .notFound:
            return .remoteServiceNotFound
        case .rateLimited:
            return .rateLimited
        case .serverUnavailable, .timeout:
            return .remoteDataDeleteFailed
        case .malformedResponse:
            return .malformedResponse
        case .unknown:
            return .unknown
        }
    }

    var terminalStatus: AccountDeletionStatus {
        switch self {
        case .offline:
            return .offline
        case .requiresRecentLogin:
            return .reauthenticationRequired
        default:
            return .failed
        }
    }

    var isRetryable: Bool {
        switch self {
        case .offline, .unauthorized, .forbidden, .notFound, .rateLimited,
             .serverUnavailable, .timeout, .malformedResponse, .requiresRecentLogin, .unknown:
            return true
        }
    }

    var logCategory: String {
        switch self {
        case .offline:
            return "offline"
        case .unauthorized:
            return "unauthorized"
        case .forbidden:
            return "forbidden"
        case .notFound:
            return "not_found"
        case .rateLimited:
            return "rate_limited"
        case .serverUnavailable:
            return "server_unavailable"
        case .timeout:
            return "timeout"
        case .malformedResponse:
            return "malformed_response"
        case .requiresRecentLogin:
            return "requires_recent_login"
        case .unknown:
            return "unknown"
        }
    }

    var userFacingMessage: String {
        switch self {
        case .offline:
            return FormaProductCopy.Settings.PrivacyData.deletionRemoteOfflineErrorMessage
        case .unauthorized:
            return FormaProductCopy.Settings.PrivacyData.deletionRemoteUnauthorizedErrorMessage
        case .forbidden:
            return FormaProductCopy.Settings.PrivacyData.deletionRemoteForbiddenErrorMessage
        case .notFound:
            return FormaProductCopy.Settings.PrivacyData.deletionRemoteNotFoundErrorMessage
        case .rateLimited:
            return FormaProductCopy.Settings.PrivacyData.deletionRemoteRateLimitedErrorMessage
        case .serverUnavailable, .timeout:
            return FormaProductCopy.Settings.PrivacyData.deletionRemoteTimeoutErrorMessage
        case .malformedResponse:
            return FormaProductCopy.Settings.PrivacyData.deletionRemoteMalformedResponseErrorMessage
        case .requiresRecentLogin:
            return FormaProductCopy.Settings.PrivacyData.deletionReauthenticationMessage
        case .unknown:
            return FormaProductCopy.Settings.PrivacyData.deletionGenericErrorMessage
        }
    }
}
