//
//  CoachMessagePresenter.swift
//  Fitness Coach
//
//  FitPilot AI — Maps chat messages to presentation styles.
//

import Foundation

enum CoachMessagePresentation: Equatable {
    case user(String)
    case confirmation(CoachConfirmationContent)
    case assistant(String)
    case system(String)
}

struct CoachConfirmationMetric: Equatable {
    let label: String
    let value: String
}

struct CoachConfirmationContent: Equatable {
    let title: String
    let metrics: [CoachConfirmationMetric]
}

enum CoachMessagePresenter {

    static func presentation(for message: ChatMessage) -> CoachMessagePresentation {
        switch message.role {
        case .user:
            return .user(message.text)
        case .system:
            return .system(message.text)
        case .assistant:
            if let confirmation = parseConfirmation(from: message.text) {
                return .confirmation(confirmation)
            }
            return .assistant(message.text)
        }
    }

    private static func parseConfirmation(from text: String) -> CoachConfirmationContent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("Logged") else { return nil }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let title = lines.first else { return nil }

        var metrics: [CoachConfirmationMetric] = []
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let label = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if !label.isEmpty, !value.isEmpty {
                    metrics.append(CoachConfirmationMetric(label: label, value: value))
                }
            } else if line.contains("/") {
                metrics.append(CoachConfirmationMetric(label: "", value: line))
            }
        }

        guard !metrics.isEmpty else { return nil }
        return CoachConfirmationContent(title: title, metrics: metrics)
    }
}
