//
//  TrainingIntegrationCopy.swift
//  Fitness Coach
//
//  Forma — User-facing copy for Apple Health training integration (Stage 2).
//

import Foundation

enum TrainingIntegrationCopy {

    static let connectAppleHealth = "Connect Apple Health"
    static let includeWorkoutsInProgress =
        "Connect Apple Health to include workouts in your progress."
    static let trainingInsightsUseAppleHealth = "Training insights use Apple Health workouts."
    static let poweredByAppleFitness = trainingInsightsUseAppleHealth
    static let poweredByAppleHealthStatus = trainingInsightsUseAppleHealth
    static let valueProposition =
        "Forma uses Apple Health workouts to show consistency, duration, and activity patterns."

    static let screenTitle = "Training Insights"

    // MARK: - Connect gate

    static let lockedTitle = screenTitle
    static let lockedBody = includeWorkoutsInProgress

    static let lockedBenefits: [String] = [
        "Workout days and duration from Apple Health",
        "Active calories and workout types",
        "Training consistency over time"
    ]

    static let lockedSecondaryNote =
        "Optional — Forma reads workouts from Apple Health. Workouts are not entered in Coach."

    static let healthShareUsageDescription =
        "Forma uses Apple Health workout data to show training consistency and progress insights."

    static let connectedEmptyTitle = "No workouts yet"
    static let connectedEmptyMessage =
        "When Apple Fitness records a workout, it will appear in Training Insights."

    static let healthIntegrationTitle = "Apple Health"
    static let healthIntegrationBody = valueProposition
    static let healthIntegrationFooter =
        "Forma reads workouts from Apple Health. It does not write or change your Health data."
    static let healthPermissionsLocationHint =
        "Workout access is managed in the Health app (Sharing → Apps → Forma), not on Forma's page in Settings."
    static let manageHealthAccess = "Open Health app"
    static let manageConnection = "Manage Apple Health connection"

    // MARK: - Plan & Settings

    static let planConnectPrompt = includeWorkoutsInProgress
    static let planConnectedNote = trainingInsightsUseAppleHealth
    static let planIntegrationSectionTitle = "Training insights"

    static let settingsStatusConnected = "Connected"
    static let settingsStatusNotConnected = "Not connected"
    static let settingsStatusAccessDenied = "Access denied"
    static let settingsStatusUnavailable = "Unavailable"

    static func planIntegrationMessage(isAppleHealthConnected: Bool) -> String {
        isAppleHealthConnected ? planConnectedNote : planConnectPrompt
    }

    static func settingsStatusLabel(for state: TrainingIntegrationState) -> String {
        switch state {
        case .connected:
            return settingsStatusConnected
        case .denied:
            return settingsStatusAccessDenied
        case .unavailable:
            return settingsStatusUnavailable
        case .notConnected, .requestingPermission, .failed:
            return settingsStatusNotConnected
        }
    }

    static func settingsDetailDescription(for state: TrainingIntegrationState) -> String {
        switch state {
        case .connected:
            return "Forma can read your workouts. Manage access in Health → Apps → Forma."
        case .notConnected:
            return "Connect Apple Health to include workouts in your Journey and Training Insights."
        case .denied:
            return "Turn on workout access in Health → Apps → Forma."
        case .unavailable:
            return unavailableMessage
        case .requestingPermission:
            return requestingMessage
        case .failed(let message):
            return failedMessage(message)
        }
    }

    // MARK: - Coach redirect

    static let coachWorkoutLogNotConnected =
        "Training insights use Apple Health workouts. Connect Apple Health to include workouts in your progress."

    static let coachWorkoutLogConnected =
        "Forma uses your Apple Health workouts for training insights. If this workout was recorded in Apple Fitness, it will appear in Training Insights."

    static let coachWorkoutMutationUnavailable =
        "Forma doesn't log workouts in Coach. Training insights use Apple Health workouts."

    static func coachWorkoutLogMessage(isAppleHealthConnected: Bool) -> String {
        isAppleHealthConnected ? coachWorkoutLogConnected : coachWorkoutLogNotConnected
    }

    static let unavailableMessage = "Apple Health is not available on this device."
    static let deniedMessage =
        "Workout access is off. Open the Health app → Apps → Forma to turn it on."

    static let unavailableTitle = "Training insights unavailable"
    static let deniedTitle = "Health access is off"
    static let requestingMessage = "Connecting to Apple Health…"
    static let openSettings = "Open Settings"

    static func failedMessage(_ message: String) -> String {
        message.isEmpty ? "We couldn't connect to Apple Health. Try again." : message
    }

    static func gateMessage(for state: TrainingIntegrationState) -> String {
        switch state {
        case .notConnected, .failed:
            return lockedBody
        case .denied:
            return deniedMessage
        case .unavailable:
            return unavailableMessage
        case .requestingPermission:
            return requestingMessage
        case .connected:
            return poweredByAppleFitness
        }
    }

    static func gateTitle(for state: TrainingIntegrationState) -> String {
        switch state {
        case .unavailable:
            return unavailableTitle
        case .denied:
            return deniedTitle
        case .notConnected, .failed, .requestingPermission, .connected:
            return screenTitle
        }
    }

    static func connectButtonTitle(for state: TrainingIntegrationState) -> String? {
        switch state {
        case .notConnected, .failed:
            return connectAppleHealth
        case .denied:
            return openSettings
        case .unavailable, .requestingPermission, .connected:
            return nil
        }
    }
}
