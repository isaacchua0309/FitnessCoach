//
//  AppleHealthSettingsActionHandler.swift
//  Fitness Coach
//
//  Forma — Primary actions for Settings → Apple Health.
//

import Foundation

enum AppleHealthSettingsActionHandler {

    static func perform(
        action: AppleHealthSettingsPrimaryAction,
        openHealthApp: () -> Void,
        connect: () async -> Void
    ) async {
        switch action {
        case .openHealthApp:
            openHealthApp()
        case .connectAppleHealth:
            await connect()
        case .none:
            break
        }
    }
}
