//
//  OnboardingAppleHealthPresentationState.swift
//  Fitness Coach
//
//  Forma — Apple Health onboarding permission UI state.
//

import Foundation

enum OnboardingAppleHealthPresentationState: Equatable, Sendable {
    case ready
    case requesting
    case connected
    case denied
    case unavailable
    case failed(message: String)

    var isRequesting: Bool {
        self == .requesting
    }

    /// Whether tapping the primary CTA should request HealthKit permission.
    var allowsPermissionRequest: Bool {
        switch self {
        case .ready, .denied, .failed:
            return true
        case .requesting, .connected, .unavailable:
            return false
        }
    }

    /// Whether the shared bottom-bar primary CTA is tappable.
    var isPrimaryActionEnabled: Bool {
        switch self {
        case .requesting, .unavailable:
            return false
        case .ready, .denied, .failed, .connected:
            return true
        }
    }

    var allowsSkip: Bool {
        !isRequesting
    }
}

enum OnboardingAppleHealthPresentationBuilder {

    static func build(
        presentation: OnboardingAppleHealthPresentationState,
        deviceState: TrainingIntegrationState
    ) -> OnboardingAppleHealthScreenState {
        let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self

        let resolvedPresentation: OnboardingAppleHealthPresentationState
        if presentation == .ready, deviceState == .unavailable {
            resolvedPresentation = .unavailable
        } else {
            resolvedPresentation = presentation
        }

        let statusMessage = statusMessage(for: resolvedPresentation, copy: copy)
        let primaryTitle = primaryTitle(for: resolvedPresentation, copy: copy)
        let heroStyle = heroStyle(for: resolvedPresentation)

        return OnboardingAppleHealthScreenState(
            presentation: resolvedPresentation,
            statusMessage: statusMessage,
            primaryTitle: primaryTitle,
            secondaryTitle: copy.skipCTA,
            heroStyle: heroStyle,
            showsSuccessCheckmark: resolvedPresentation == .connected,
            isPrimaryEnabled: resolvedPresentation.isPrimaryActionEnabled,
            isSkipEnabled: resolvedPresentation.allowsSkip,
            accessibilitySummary: accessibilitySummary(copy: copy)
        )
    }

    static func mapPermissionResult(_ state: TrainingIntegrationState) -> OnboardingAppleHealthPresentationState {
        switch state {
        case .connected:
            return .connected
        case .denied:
            return .denied
        case .unavailable:
            return .unavailable
        case .failed(let message):
            return .failed(message: message)
        case .notConnected, .requestingPermission:
            return .ready
        }
    }

    private static func statusMessage(
        for presentation: OnboardingAppleHealthPresentationState,
        copy: FormaProductCopy.Onboarding.Flow.AppleHealth.Type
    ) -> String? {
        switch presentation {
        case .ready:
            return nil
        case .requesting:
            return copy.requestingMessage
        case .connected:
            return copy.connectedMessage
        case .denied:
            return copy.deniedMessage
        case .unavailable:
            return copy.unavailableMessage
        case .failed:
            return copy.failedMessage
        }
    }

    private static func primaryTitle(
        for presentation: OnboardingAppleHealthPresentationState,
        copy: FormaProductCopy.Onboarding.Flow.AppleHealth.Type
    ) -> String {
        switch presentation {
        case .unavailable:
            return copy.unavailableCTA
        case .connected:
            return copy.connectedCTA
        default:
            return copy.connectCTA
        }
    }

    private static func heroStyle(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> OnboardingAppleHealthHeroStyle {
        switch presentation {
        case .requesting:
            return .loading
        case .connected:
            return .success
        default:
            return .heart
        }
    }

    private static func accessibilitySummary(
        copy: FormaProductCopy.Onboarding.Flow.AppleHealth.Type
    ) -> String {
        "\(copy.title). Optional. \(copy.subtitle)"
    }
}

struct OnboardingAppleHealthScreenState: Equatable, Sendable {
    let presentation: OnboardingAppleHealthPresentationState
    let statusMessage: String?
    let primaryTitle: String
    let secondaryTitle: String
    let heroStyle: OnboardingAppleHealthHeroStyle
    let showsSuccessCheckmark: Bool
    let isPrimaryEnabled: Bool
    let isSkipEnabled: Bool
    let accessibilitySummary: String
}

enum OnboardingAppleHealthHeroStyle: Equatable, Sendable {
    case heart
    case loading
    case success
}
