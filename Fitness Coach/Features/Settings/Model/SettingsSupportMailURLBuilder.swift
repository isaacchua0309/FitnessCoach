//
//  SettingsSupportMailURLBuilder.swift
//  Fitness Coach
//
//  Forma — mailto URLs for Settings support actions.
//

import Foundation

enum SettingsSupportMailURLBuilder {

    static func url(
        for topic: SettingsSupportMailTopic,
        supportEmail: String,
        diagnostics: SettingsSupportDiagnostics
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: SettingsSupportMailContent.subject(for: topic)
            ),
            URLQueryItem(
                name: "body",
                value: SettingsSupportMailContent.messageBody(for: topic, diagnostics: diagnostics)
            )
        ]
        return components.url
    }
}
