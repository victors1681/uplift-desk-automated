//
//  DeskTimerManager.swift
//  uplift-desk-automated
//
//  Created by Victor Santos on 12/22/25.
//  Manages desk position timers and reminders
//

import Foundation
import UserNotifications
import Combine

enum DeskPosition {
    case sitting
    case standing
    case unknown
}

class DeskTimerManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentPosition: DeskPosition = .unknown
    @Published var timeInCurrentPosition: TimeInterval = 0
    @Published var totalStandingTimeToday: TimeInterval = 0
    @Published var isTimerActive: Bool = false
    @Published var nextReminderIn: TimeInterval = 0
    @Published var isPaused: Bool = UserDefaults.standard.bool(forKey: "automationPaused")

    // MARK: - Private Properties
    private var positionTimer: Timer?
    private var reminderTimer: Timer?
    private var countdownTimer: Timer?
    private var positionStartTime: Date?
    private var lastDateTracked: Date?

    private let settingsManager: TimerSettingsManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(settingsManager: TimerSettingsManager) {
        self.settingsManager = settingsManager
        loadDailyStats()
        requestNotificationPermission()

        // Observe settings changes
        settingsManager.$settings
            .sink { [weak self] settings in
                guard let self = self else { return }

                if settings.timerEnabled {
                    if !self.isTimerActive {
                        // Timer was just enabled
                        self.startTimer()
                    } else {
                        // Timer is already active, reschedule reminder if interval changed
                        self.scheduleNextReminder()
                        print("⏰ Settings changed, rescheduling reminder")
                    }
                } else {
                    self.stopTimer()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Timer Control
    func startTimer() {
        guard !isTimerActive else { return }
        isTimerActive = true
        positionStartTime = Date()

        // Start position tracking timer (updates every second)
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePositionTime()
        }

        // Schedule first reminder
        scheduleNextReminder()

        print("⏰ Timer started")
    }

    func togglePause() {
        isPaused.toggle()
        UserDefaults.standard.set(isPaused, forKey: "automationPaused")
    }

    func stopTimer() {
        isTimerActive = false
        positionTimer?.invalidate()
        positionTimer = nil
        reminderTimer?.invalidate()
        reminderTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil

        print("⏰ Timer stopped")
    }

    // MARK: - Position Tracking
    func updatePosition(_ position: DeskPosition) {
        // Save time from previous position
        if let startTime = positionStartTime, currentPosition == .standing {
            let duration = Date().timeIntervalSince(startTime)
            totalStandingTimeToday += duration
            saveDailyStats()
        }

        // Update to new position
        currentPosition = position
        positionStartTime = Date()
        timeInCurrentPosition = 0

        print("📍 Position updated to: \(position)")
        print("📊 Total standing today: \(formatTime(totalStandingTimeToday))")

        // Reset reminder timer
        if isTimerActive {
            scheduleNextReminder()
        }
    }

    private func updatePositionTime() {
        guard let startTime = positionStartTime else { return }
        timeInCurrentPosition = Date().timeIntervalSince(startTime)

        // Update standing time if currently standing
        if currentPosition == .standing {
            saveDailyStats()
        }

        // Check if it's a new day and reset stats
        checkAndResetDailyStats()
    }

    // MARK: - Reminders
    private func scheduleNextReminder() {
        // Cancel any existing timers
        reminderTimer?.invalidate()
        countdownTimer?.invalidate()

        let intervalSeconds = TimeInterval(settingsManager.settings.reminderIntervalMinutes * 60)
        nextReminderIn = intervalSeconds

        print("⏱️ Scheduling next reminder in \(settingsManager.settings.reminderIntervalMinutes) minutes")

        reminderTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: false) { [weak self] _ in
            self?.triggerReminder()
        }

        // Update countdown every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isTimerActive else {
                timer.invalidate()
                return
            }
            if !self.isPaused {
                self.nextReminderIn = max(0, self.nextReminderIn - 1)
            }
        }
    }

    private func triggerReminder() {
        // Skip if automation is paused
        if isPaused {
            scheduleNextReminder()
            return
        }

        // Check if working hours are enabled and if we're within working hours
        if settingsManager.settings.workingHoursEnabled && !isWithinWorkingHours() {
            print("⏰ Skipping reminder - outside working hours")
            // Schedule next reminder to check again
            scheduleNextReminder()
            return
        }

        let nextPosition: DeskPosition = currentPosition == .sitting ? .standing : .sitting
        let message = nextPosition == .standing
            ? "Time to stand up! You've been sitting for \(formatTime(timeInCurrentPosition))"
            : "Time to sit down! You've been standing for \(formatTime(timeInCurrentPosition))"

        print("🔔 Reminder: \(message)")

        if settingsManager.settings.notificationsEnabled {
            sendNotification(title: "Desk Position Reminder", body: message)
        }

        // Auto-move if enabled
        if settingsManager.settings.autoMoveDesk {
            NotificationCenter.default.post(
                name: NSNotification.Name("AutoMoveDeskNotification"),
                object: nil,
                userInfo: ["position": nextPosition]
            )
        }

        // Schedule next reminder
        scheduleNextReminder()
    }

    private func isWithinWorkingHours() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        let startHour = settingsManager.settings.workingHoursStart
        let endHour = settingsManager.settings.workingHoursEnd

        // Handle case where end time is on the next day (e.g., 22:00 to 06:00)
        if startHour < endHour {
            return currentHour >= startHour && currentHour < endHour
        } else {
            return currentHour >= startHour || currentHour < endHour
        }
    }

    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = settingsManager.settings.soundEnabled ? .default : nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Daily Stats
    private func loadDailyStats() {
        let today = Calendar.current.startOfDay(for: Date())

        if let savedDate = UserDefaults.standard.object(forKey: "lastTrackedDate") as? Date,
           Calendar.current.isDate(savedDate, inSameDayAs: today) {
            // Load today's stats
            totalStandingTimeToday = UserDefaults.standard.double(forKey: "totalStandingTimeToday")
            lastDateTracked = savedDate
        } else {
            // New day, reset stats
            totalStandingTimeToday = 0
            lastDateTracked = today
            saveDailyStats()
        }
    }

    private func saveDailyStats() {
        UserDefaults.standard.set(totalStandingTimeToday, forKey: "totalStandingTimeToday")
        UserDefaults.standard.set(Date(), forKey: "lastTrackedDate")
    }

    private func checkAndResetDailyStats() {
        let today = Calendar.current.startOfDay(for: Date())

        if let lastDate = lastDateTracked,
           !Calendar.current.isDate(lastDate, inSameDayAs: today) {
            // New day detected, reset stats
            print("📅 New day detected, resetting stats")
            totalStandingTimeToday = 0
            lastDateTracked = today
            saveDailyStats()
        }
    }

    // MARK: - Helpers
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    func getStandingProgress() -> Double {
        let goalSeconds = TimeInterval(settingsManager.settings.dailyStandingGoalMinutes * 60)
        return min(1.0, totalStandingTimeToday / goalSeconds)
    }

    func getRemainingStandingTime() -> TimeInterval {
        let goalSeconds = TimeInterval(settingsManager.settings.dailyStandingGoalMinutes * 60)
        return max(0, goalSeconds - totalStandingTimeToday)
    }
}
