//
//  OnboardingAppleHealthPresentationState.swift
//  Fitness Coach
//
//  Forma — Apple Health onboarding permission UI state.
//

import Foundation

enum OnboardingAppleHealthPresentationState: Equatable, Sendable {
    case notDetermined
    case requesting
    case connected
    case denied
    case unavailable
    case failed(message: String)

    var isRequesting: Bool {
        self == .requesting
    }
}

enum OnboardingAppleHealthPrimaryAction: Equatable, Sendable {
    case requestPermission
    case advance
    case openSettings
}

enum OnboardingAppleHealthPresentationBuilder {

    static func build(
        presentation: OnboardingAppleHealthPresentationState,
        deviceState: TrainingIntegrationState
    ) -> OnboardingAppleHealthScreenState {
        let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self

        let resolvedPresentation = resolvePresentation(
            presentation: presentation,
            deviceState: deviceState
        )

        return OnboardingAppleHealthScreenState(
            presentation: resolvedPresentation,
            statusMessage: statusMessage(for: resolvedPresentation, copy: copy),
            primaryTitle: primaryTitle(for: resolvedPresentation, copy: copy),
            skipTitle: copy.skipCTA,
            showsSkipButton: showsSkipButton(for: resolvedPresentation),
            heroStyle: heroStyle(for: resolvedPresentation),
            showsHeroIcon: showsHeroIcon(for: resolvedPresentation),
            showsPermissionCard: showsPermissionCard(for: resolvedPresentation),
            showsPrivacyCard: showsPrivacyCard(for: resolvedPresentation),
            isPrimaryEnabled: isPrimaryEnabled(for: resolvedPresentation),
            primaryAction: primaryAction(for: resolvedPresentation),
            accessibilitySummary: accessibilitySummary(
                for: resolvedPresentation,
                copy: copy
            )
        )
    }

    static func mapPermissionResult(
        _ state: TrainingIntegrationState
    ) -> OnboardingAppleHealthPresentationState {
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
            return .notDetermined
        }
    }

    private static func resolvePresentation(
        presentation: OnboardingAppleHealthPresentationState,
        deviceState: TrainingIntegrationState
    ) -> OnboardingAppleHealthPresentationState {
        if presentation == .connected, deviceState != .connected {
            return mapPermissionResult(deviceState)
        }

        if presentation == .requesting {
            switch deviceState {
            case .connected:
                return .connected
            case .denied:
                return .denied
            case .unavailable:
                return .unavailable
            case .failed(let message):
                return .failed(message: message)
            case .notConnected, .requestingPermission:
                return .requesting
            }
        }

        if presentation == .notDetermined, deviceState == .unavailable {
            return .unavailable
        }
        if presentation == .notDetermined, deviceState == .connected {
            return .connected
        }
        if presentation == .notDetermined, deviceState == .denied {
            return .denied
        }
        return presentation
    }

    private static func showsSkipButton(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> Bool {
        switch presentation {
        case .notDetermined, .failed:
            return true
        case .requesting, .connected, .denied, .unavailable:
            return false
        }
    }

    private static func showsHeroIcon(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> Bool {
        switch presentation {
        case .connected:
            return false
        case .notDetermined, .requesting, .denied, .unavailable, .failed:
            return true
        }
    }

    private static func showsPermissionCard(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> Bool {
        presentation != .unavailable
    }

    private static func showsPrivacyCard(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> Bool {
        true
    }

    private static func isPrimaryEnabled(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> Bool {
        presentation != .requesting
    }

    private static func primaryAction(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> OnboardingAppleHealthPrimaryAction {
        switch presentation {
        case .notDetermined, .failed:
            return .requestPermission
        case .connected, .denied, .unavailable:
            return .advance
        case .requesting:
            return .requestPermission
        }
    }

    private static func statusMessage(
        for presentation: OnboardingAppleHealthPresentationState,
        copy: FormaProductCopy.Onboarding.Flow.AppleHealth.Type
    ) -> String? {
        switch presentation {
        case .notDetermined:
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
        case .notDetermined, .failed:
            return copy.connectCTA
        case .requesting:
            return copy.connectCTA
        case .connected, .denied, .unavailable:
            return copy.continueCTA
        }
    }

    private static func heroStyle(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> OnboardingAppleHealthHeroStyle {
        presentation == .requesting ? .loading : .heart
    }

    private static func accessibilitySummary(
        for presentation: OnboardingAppleHealthPresentationState,
        copy: FormaProductCopy.Onboarding.Flow.AppleHealth.Type
    ) -> String {
        switch presentation {
        case .connected:
            return "\(copy.title). \(copy.connectedMessage)"
        case .unavailable:
            return "\(copy.title). \(copy.unavailableMessage)"
        default:
            return "\(copy.title). Optional. \(copy.subtitle)"
        }
    }
}

struct OnboardingAppleHealthScreenState: Equatable, Sendable {
    let presentation: OnboardingAppleHealthPresentationState
    let statusMessage: String?
    let primaryTitle: String
    let skipTitle: String
    let showsSkipButton: Bool
    let heroStyle: OnboardingAppleHealthHeroStyle
    let showsHeroIcon: Bool
    let showsPermissionCard: Bool
    let showsPrivacyCard: Bool
    let isPrimaryEnabled: Bool
    let primaryAction: OnboardingAppleHealthPrimaryAction
    let accessibilitySummary: String
}

enum OnboardingAppleHealthHeroStyle: Equatable, Sendable {
    case heart
    case loading
}
