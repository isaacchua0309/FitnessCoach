//
//  SettingsSupportDeviceInfo.swift
//  Fitness Coach
//
//  Forma — Device metadata for support diagnostics.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum SettingsSupportDeviceInfo {

    static var deviceModel: String {
        #if canImport(UIKit)
        return hardwareIdentifier() ?? UIDevice.current.model
        #else
        return "Unknown device"
        #endif
    }

    static var systemVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    #if canImport(UIKit)
    private static func hardwareIdentifier() -> String? {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return nil }

        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { charPointer in
                String(validatingUTF8: charPointer)
            }
        }
    }
    #endif
}
