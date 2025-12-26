//
//  TimerSettings.swift
//  uplift-desk-automated
//
//  Created by Victor Santos on 12/22/25.
//  Timer and reminder settings for desk automation
//

import Foundation

struct TimerSettings: Codable {
    // Daily standing goal in minutes (1 min to 480 min / 8 hours)
    var dailyStandingGoalMinutes: Int = 240  // Default: 4 hours

    // Interval between position changes in minutes (1 min to 120 min / 2 hours)
    var reminderIntervalMinutes: Int = 30  // Default: 30 minutes

    // Auto-move desk or just notify
    var autoMoveDesk: Bool = false  // Default: notify only

    // Enable/disable timer system
    var timerEnabled: Bool = false

    // Test mode for quick testing
    var testModeEnabled: Bool = false  // Default: normal mode

    // Notification preferences
    var notificationsEnabled: Bool = true
    var soundEnabled: Bool = true

    // Working hours (24-hour format)
    var workingHoursEnabled: Bool = false
    var workingHoursStart: Int = 9  // 9 AM
    var workingHoursEnd: Int = 17  // 5 PM
}

class TimerSettingsManager: ObservableObject {
    @Published var settings: TimerSettings {
        didSet {
            saveSettings()
        }
    }

    private let userDefaultsKey = "upliftDeskTimerSettings"

    init() {
        // Load saved settings or use defaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedSettings = try? JSONDecoder().decode(TimerSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            self.settings = TimerSettings()
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
