//
//  SettingsSupportMailURLBuilder.swift
//  Fitness Coach
//
//  Forma — mailto URLs for Settings support actions.
//

import Foundation

enum SettingsSupportMailURLBuilder {

    static func url(for topic: SettingsSupportMailTopic) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = FormaProductCopy.Legal.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject(for: topic))
        ]
        return components.url
    }

    private static func subject(for topic: SettingsSupportMailTopic) -> String {
        switch topic {
        case .feedback:
            return FormaProductCopy.Settings.Support.feedbackMailSubject
        case .contactSupport:
            return FormaProductCopy.Settings.Support.contactMailSubject
        case .reportProblem:
            return FormaProductCopy.Settings.Support.reportProblemMailSubject
        }
    }
}
