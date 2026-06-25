//
//  AppRefreshCenter.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight cross-tab refresh signal.
//
//  Signals that shared data changed. It does not know what changed,
//  call services, or contain business logic.
//

import Combine
import Foundation
import UIKit

@MainActor
final class AppRefreshCenter: ObservableObject {

    @Published private(set) var refreshToken: Int = 0

    private var lastKnownDayStart: Date
    private var cancellables = Set<AnyCancellable>()

    init(now: Date = Date()) {
        lastKnownDayStart = Calendar.current.startOfDay(for: now)

        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .sink { [weak self] _ in self?.refreshIfDayChanged() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in self?.refreshIfDayChanged() }
            .store(in: &cancellables)
    }

    func notifyDataChanged() {
        refreshToken += 1
    }

    /// Call when the app becomes active so tabs reload if the calendar day changed.
    func refreshIfDayChanged(now: Date = Date()) {
        let todayStart = Calendar.current.startOfDay(for: now)
        guard todayStart != lastKnownDayStart else { return }
        lastKnownDayStart = todayStart
        notifyDataChanged()
    }
}
