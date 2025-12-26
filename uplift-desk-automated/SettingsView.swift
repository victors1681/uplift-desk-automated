//
//  SettingsView.swift
//  uplift-desk-automated
//
//  Created by Victor Santos on 12/22/25.
//  Settings view for timer and automation configuration
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: TimerSettingsManager
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Timer Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                Form {
                // Connection Settings
                Section {
                    Toggle("Auto-Connect on Launch", isOn: Binding(
                        get: { bluetoothManager.autoConnectEnabled },
                        set: { newValue in
                            bluetoothManager.autoConnectEnabled = newValue
                            UserDefaults.standard.set(newValue, forKey: "autoConnectEnabled")
                        }
                    ))
                    .toggleStyle(.switch)

                    if let lastUUID = UserDefaults.standard.string(forKey: "lastConnectedDeskUUID") {
                        HStack {
                            Text("Last Connected")
                            Spacer()
                            Text(String(lastUUID.prefix(8)) + "...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Automatically connect to your last used desk when opening the app")
                }

                // Test Mode Toggle
                Section {
                    Toggle("Test Mode", isOn: $settingsManager.settings.testModeEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: settingsManager.settings.testModeEnabled) { newValue in
                            if newValue {
                                // Switch to test mode defaults
                                settingsManager.settings.dailyStandingGoalMinutes = 5
                                settingsManager.settings.reminderIntervalMinutes = 2
                            } else {
                                // Switch back to normal defaults
                                settingsManager.settings.dailyStandingGoalMinutes = 240
                                settingsManager.settings.reminderIntervalMinutes = 30
                            }
                        }
                } header: {
                    Text("Testing")
                } footer: {
                    Text("Enable for quick testing with minute-level intervals (disables normal hour-based settings)")
                }

                // Timer Enable/Disable
                Section {
                    Toggle("Enable Position Timer", isOn: $settingsManager.settings.timerEnabled)
                        .toggleStyle(.switch)
                } header: {
                    Text("Timer")
                } footer: {
                    Text("Automatically reminds you to alternate between sitting and standing")
                }

                // Daily Goal - Different for Test Mode vs Normal Mode
                if settingsManager.settings.testModeEnabled {
                    // TEST MODE: Simple minute controls
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            // Goal in minutes
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Daily Standing Goal")
                                    Spacer()
                                    Text("\(settingsManager.settings.dailyStandingGoalMinutes) minutes")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(settingsManager.settings.dailyStandingGoalMinutes) },
                                        set: { settingsManager.settings.dailyStandingGoalMinutes = Int($0) }
                                    ),
                                    in: 1...10,
                                    step: 1
                                )

                                HStack {
                                    Text("1 min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("10 min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Divider()

                            // Quick presets for testing
                            HStack(spacing: 12) {
                                Button("2 min") {
                                    settingsManager.settings.dailyStandingGoalMinutes = 2
                                }
                                .buttonStyle(.bordered)

                                Button("5 min") {
                                    settingsManager.settings.dailyStandingGoalMinutes = 5
                                }
                                .buttonStyle(.bordered)

                                Button("10 min") {
                                    settingsManager.settings.dailyStandingGoalMinutes = 10
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Goals (Test Mode)")
                    } footer: {
                        Text("Set a very short goal for quick testing. Current: \(settingsManager.settings.dailyStandingGoalMinutes) minutes")
                    }
                } else {
                    // NORMAL MODE: Hour-based controls
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Daily Standing Goal")
                                Spacer()
                                Text(formatGoal())
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(settingsManager.settings.dailyStandingGoalMinutes) },
                                    set: { settingsManager.settings.dailyStandingGoalMinutes = Int($0) }
                                ),
                                in: 60...480,
                                step: 30
                            )

                            HStack {
                                Text("1 hour")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("8 hours")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Goals")
                    } footer: {
                        Text("How much time you want to spend standing each day")
                    }
                }

                // Reminder Interval - Different for Test Mode
                if settingsManager.settings.testModeEnabled {
                    // TEST MODE: Very short intervals
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Reminder Interval")
                                    Spacer()
                                    Text("\(settingsManager.settings.reminderIntervalMinutes) minutes")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(settingsManager.settings.reminderIntervalMinutes) },
                                        set: { settingsManager.settings.reminderIntervalMinutes = Int($0) }
                                    ),
                                    in: 1...5,
                                    step: 1
                                )

                                HStack {
                                    Text("1 min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("5 min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Divider()

                            // Quick preset buttons
                            HStack(spacing: 12) {
                                Button("1 min") {
                                    settingsManager.settings.reminderIntervalMinutes = 1
                                }
                                .buttonStyle(.bordered)

                                Button("2 min") {
                                    settingsManager.settings.reminderIntervalMinutes = 2
                                }
                                .buttonStyle(.bordered)

                                Button("3 min") {
                                    settingsManager.settings.reminderIntervalMinutes = 3
                                }
                                .buttonStyle(.bordered)

                                Button("5 min") {
                                    settingsManager.settings.reminderIntervalMinutes = 5
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Reminders (Test Mode)")
                    } footer: {
                        Text("How often to alternate positions during testing. Keep it short!")
                    }
                } else {
                    // NORMAL MODE: Standard intervals
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reminder Interval")
                                Spacer()
                                Text("\(settingsManager.settings.reminderIntervalMinutes) min")
                                    .foregroundColor(.secondary)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(settingsManager.settings.reminderIntervalMinutes) },
                                    set: { settingsManager.settings.reminderIntervalMinutes = Int($0) }
                                ),
                                in: 15...120,
                                step: 15
                            )

                            HStack {
                                Text("15 min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("2 hours")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Reminders")
                    } footer: {
                        Text("How often to remind you to change positions")
                    }
                }

                // Automation
                Section {
                    Toggle("Auto-Move Desk", isOn: $settingsManager.settings.autoMoveDesk)
                        .toggleStyle(.switch)
                } header: {
                    Text("Automation")
                } footer: {
                    Text("Automatically move desk when reminder triggers (instead of just notifying)")
                }

                // Working Hours
                Section {
                    Toggle("Enable Working Hours", isOn: $settingsManager.settings.workingHoursEnabled)
                        .toggleStyle(.switch)

                    if settingsManager.settings.workingHoursEnabled {
                        HStack {
                            Text("Start Time")
                            Spacer()
                            Picker("Start", selection: $settingsManager.settings.workingHoursStart) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
                        }

                        HStack {
                            Text("End Time")
                            Spacer()
                            Picker("End", selection: $settingsManager.settings.workingHoursEnd) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
                        }
                    }
                } header: {
                    Text("Working Hours")
                } footer: {
                    if settingsManager.settings.workingHoursEnabled {
                        Text("Reminders will only trigger between \(formatHour(settingsManager.settings.workingHoursStart)) and \(formatHour(settingsManager.settings.workingHoursEnd))")
                    } else {
                        Text("Limit reminders to specific hours of the day")
                    }
                }

                // Notifications
                Section {
                    Toggle("Notifications", isOn: $settingsManager.settings.notificationsEnabled)
                        .toggleStyle(.switch)

                    Toggle("Sound", isOn: $settingsManager.settings.soundEnabled)
                        .toggleStyle(.switch)
                        .disabled(!settingsManager.settings.notificationsEnabled)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Show notifications when it's time to change positions")
                }

                // Presets - Only show in normal mode (test mode has inline buttons)
                if !settingsManager.settings.testModeEnabled {
                    Section {
                        VStack(spacing: 12) {
                            PresetButton(
                                title: "Office Worker",
                                description: "4 hrs standing, 30 min intervals",
                                action: {
                                    settingsManager.settings.dailyStandingGoalMinutes = 240
                                    settingsManager.settings.reminderIntervalMinutes = 30
                                }
                            )

                            PresetButton(
                                title: "Moderate",
                                description: "2 hrs standing, 45 min intervals",
                                action: {
                                    settingsManager.settings.dailyStandingGoalMinutes = 120
                                    settingsManager.settings.reminderIntervalMinutes = 45
                                }
                            )

                            PresetButton(
                                title: "Beginner",
                                description: "1 hr standing, 60 min intervals",
                                action: {
                                    settingsManager.settings.dailyStandingGoalMinutes = 60
                                    settingsManager.settings.reminderIntervalMinutes = 60
                                }
                            )
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Presets")
                    }
                }
                }
                
                .formStyle(.grouped)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .frame(minWidth: 400, idealWidth: 700, maxWidth: .infinity, minHeight: 750, idealHeight: 850, maxHeight: .infinity)
    }

    // MARK: - Helper Functions

    private func formatGoal() -> String {
        let minutes = settingsManager.settings.dailyStandingGoalMinutes
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins > 0 {
                return "\(hours)h \(remainingMins)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"  // 12-hour format with AM/PM
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(settingsManager: TimerSettingsManager(), bluetoothManager: BluetoothManager())
}
