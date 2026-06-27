//
//  TrainingIntegrationCopy.swift
//  Fitness Coach
//
//  Forma — User-facing copy for Apple Health training integration (Stage 2).
//

import Foundation

enum TrainingIntegrationCopy {

    static let connectAppleHealth = "Connect Apple Health"
    static let poweredByAppleFitness = "Training insights are powered by Apple Fitness."
    static let poweredByAppleHealthStatus = "Powered by Apple Health"
    static let valueProposition =
        "Forma uses your workout data to show consistency, duration, and activity patterns."

    static let screenTitle = "Training Insights"

    // MARK: - Locked gate (Stage 3)

    static let lockedTitle = "Unlock Training Insights"
    static let lockedBody =
        "Connect Apple Health to let Forma understand your workouts, activity, and recovery patterns."

    static let lockedBenefits: [String] = [
        "Workout days and duration",
        "Active calories and workout types",
        "Training consistency over time"
    ]

    static let lockedSecondaryNote =
        "Training data comes from Apple Health. Forma will not manually create workout records."

    static let healthShareUsageDescription =
        "Forma uses Apple Health workout data to show training consistency and progress insights."

    static let connectedEmptyTitle = "Waiting for your workouts"
    static let connectedEmptyMessage =
        "No Apple Health workouts found yet. Once your workouts appear in Apple Fitness, Forma will show your training insights here."

    static let healthIntegrationTitle = "Apple Health"
    static let healthIntegrationBody = TrainingIntegrationCopy.valueProposition
    static let healthIntegrationFooter =
        "Forma reads workouts from Apple Health. It does not write or change your Health data."
    static let healthPermissionsLocationHint =
        "Workout access is managed in the Health app (Sharing → Apps → Forma), not on Forma's page in Settings."
    static let manageHealthAccess = "Open Health app"
    static let manageConnection = "Manage Apple Health connection"

    // MARK: - Plan & Settings (Stage 10)

    static let planConnectPrompt = "Connect Apple Health for automatic training insights."
    static let planConnectedNote = "Training insights powered by Apple Health."
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
            return "Connect to see workout days, duration, and consistency in Forma."
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

    // MARK: - Coach redirect (Stage 7)

    static let coachWorkoutLogNotConnected =
        "Training insights come from Apple Health. Connect Apple Health to let Forma understand your workouts automatically."

    static let coachWorkoutLogConnected =
        "Forma uses your Apple Health workouts for training insights. If this workout was recorded in Apple Fitness, it will appear in your Training Insights."

    static let coachWorkoutMutationUnavailable =
        "Forma doesn't log workouts in Coach. Training insights come from Apple Health."

    static func coachWorkoutLogMessage(isAppleHealthConnected: Bool) -> String {
        isAppleHealthConnected ? coachWorkoutLogConnected : coachWorkoutLogNotConnected
    }

    static let unavailableMessage = "Apple Health is not available on this device."
    static let deniedMessage =
        "Workout access is off. Open the Health app → Apps → Forma to turn it on."

    static let gateTitle = "Training Insights"
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
        case .notConnected, .failed, .requestingPermission:
            return lockedTitle
        case .connected:
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
