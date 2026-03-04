//
//  ContentView.swift
//  uplift-desk-automated
//
//  Created by Victor Santos on 12/22/25.
//  Main view for the Uplift Desk Controller app
//

import SwiftUI
import CoreBluetooth
import AppKit

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var settingsManager = TimerSettingsManager()
    @StateObject private var timerManager: DeskTimerManager

    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var showingAutoMoveWarning = false
    @State private var autoMoveCountdown = 5
    @State private var autoMoveCountdownTimer: Timer?
    @State private var autoMoveTargetPosition: DeskPosition = .unknown

    init() {
        let settings = TimerSettingsManager()
        let timer = DeskTimerManager(settingsManager: settings)
        _settingsManager = StateObject(wrappedValue: settings)
        _timerManager = StateObject(wrappedValue: timer)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Uplift Desk Controller")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                if timerManager.isTimerActive {
                    Button(action: {
                        timerManager.togglePause()
                    }) {
                        Image(systemName: timerManager.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title2)
                            .foregroundColor(timerManager.isPaused ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(timerManager.isPaused ? "Resume automation" : "Pause automation")
                }
                Button(action: {
                    showingSettings = true
                }) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                // Connection Status
                connectionStatusSection

                if bluetoothManager.connectedDesk != nil {
                    Divider()

                    // Height Display
                    heightDisplaySection

                    // Timer Status (if enabled)
                    if timerManager.isTimerActive {
                        Divider()
                        timerStatusSection
                    }

                    Divider()

                    // Controls
                    controlsSection
                } else {
                    Spacer()

                    // Connect Button
                    Button(action: {
                        showingScanner = true
                    }) {
                        Label("Connect to Desk", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity) 
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(bluetoothManager.bluetoothState != .poweredOn)
                    .padding(.horizontal)

                    if bluetoothManager.bluetoothState != .poweredOn {
                        Text("Please enable Bluetooth to connect")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                }
                .padding()
            }
        }
        .frame(width: 340)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Divider()
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingScanner) {
            DeskScannerView(bluetoothManager: bluetoothManager, isPresented: $showingScanner)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settingsManager: settingsManager, bluetoothManager: bluetoothManager)
        }
        .onAppear {
            setupNotificationObserver()
        }
        .alert(autoMoveAlertTitle, isPresented: $showingAutoMoveWarning) {
            Button("CANCEL", role: .cancel) {
                cancelAutoMoveSequence()
                showingAutoMoveWarning = false
            }
        } message: {
            Text(autoMoveAlertMessage)
        }
    }

    // MARK: - View Components

    private var connectionStatusSection: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 12, height: 12)

                Text(connectionStatusText)
                    .font(.headline)

                if bluetoothManager.isAutoConnecting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }

                Spacer()

                if bluetoothManager.connectedDesk != nil {
                    Button(action: {
                        bluetoothManager.disconnect()
                    }) {
                        Text("Disconnect")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let desk = bluetoothManager.connectedDesk {
                HStack {
                    Text(desk.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if bluetoothManager.isAutoConnecting {
                HStack {
                    Text("Searching for saved desk...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var connectionStatusText: String {
        if bluetoothManager.connectedDesk != nil {
            return "Connected"
        } else if bluetoothManager.isAutoConnecting {
            return "Connecting..."
        } else {
            return "Not Connected"
        }
    }

    private var connectionStatusColor: Color {
        if bluetoothManager.connectedDesk != nil {
            return .green
        } else if bluetoothManager.isAutoConnecting {
            return .orange
        } else {
            return .gray
        }
    }

    private var heightDisplaySection: some View {
        VStack(spacing: 8) {
            Text("Current Height")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", bluetoothManager.currentHeight))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("inches")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            if bluetoothManager.isMoving {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 12, height: 12)
                    Text("Moving...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Preset Buttons
            HStack(spacing: 16) {
                Button(action: {
                    bluetoothManager.moveToSitting()
                    timerManager.updatePosition(.sitting)
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "chair.fill")
                            .font(.title)
                        Text("Sitting")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.30, green: 0.45, blue: 0.70))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    // Manual move - no warning needed
                    bluetoothManager.moveToStanding()
                    timerManager.updatePosition(.standing)
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.stand")
                            .font(.title)
                        Text("Standing")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.20, green: 0.65, blue: 0.55))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // Manual Control Buttons
            VStack(spacing: 12) {
                Button(action: {
                    bluetoothManager.pressRaise()
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Raise")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.85, green: 0.55, blue: 0.35))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    bluetoothManager.pressLower()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Lower")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.45, green: 0.40, blue: 0.75))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // Refresh Button
            Button(action: {
                bluetoothManager.readHeight()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Height")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var timerStatusSection: some View {
        VStack(spacing: 12) {
            // Paused banner
            if timerManager.isPaused {
                HStack(spacing: 6) {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(.orange)
                    Text("Automation paused — desk won't move automatically")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            }

            // Position and Time
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Position")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(positionColor)
                            .frame(width: 8, height: 8)
                        Text(positionText)
                            .font(.headline)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Time in Position")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(timerManager.timeInCurrentPosition))
                        .font(.headline)
                        .monospacedDigit()
                }
            }

            // Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Daily Standing Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(formatTime(timerManager.totalStandingTimeToday)) / \(settingsManager.settings.dailyStandingGoalMinutes / 60)h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: timerManager.getStandingProgress())
                    .progressViewStyle(.linear)
                    .tint(progressColor)
            }

            // Next Reminder
            if timerManager.nextReminderIn > 0 {
                HStack {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Next reminder in \(formatTime(timerManager.nextReminderIn))")
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Helper Functions

    private var autoMoveAlertTitle: String {
        switch autoMoveTargetPosition {
        case .standing:
            return "⚠️ TIMER: DESK WILL RAISE"
        case .sitting:
            return "⚠️ TIMER: DESK WILL LOWER"
        case .unknown:
            return "⚠️ TIMER: DESK WILL MOVE"
        }
    }

    private var autoMoveAlertMessage: String {
        let action = autoMoveTargetPosition == .standing ? "RAISING" : "LOWERING"
        return "🚨 DESK \(action) IN \(autoMoveCountdown) SECONDS 🚨\n\n⚡️ Please clear any obstacles immediately!\n\n✋ Click CANCEL to stop"
    }

    private var positionText: String {
        switch timerManager.currentPosition {
        case .sitting: return "Sitting"
        case .standing: return "Standing"
        case .unknown: return "Unknown"
        }
    }

    private var positionColor: Color {
        switch timerManager.currentPosition {
        case .sitting: return .blue
        case .standing: return .green
        case .unknown: return .gray
        }
    }

    private var progressColor: Color {
        let progress = timerManager.getStandingProgress()
        if progress >= 0.8 {
            return .green
        } else if progress >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func setupNotificationObserver() {
        // Listen for auto-move notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AutoMoveDeskNotification"),
            object: nil,
            queue: .main
        ) { notification in
            if let position = notification.userInfo?["position"] as? DeskPosition {
                handleAutoMove(to: position)
            }
        }
    }

    private func handleAutoMove(to position: DeskPosition) {
        guard bluetoothManager.connectedDesk != nil else { return }

        // Store target position
        autoMoveTargetPosition = position

        // Show warning and start sequence
        showingAutoMoveWarning = true
        autoMoveCountdown = 5
        startAutoMoveSequence()
    }
}

// Helper extension for ContentView to update button actions
extension ContentView {
    func moveToSittingWithTimer() {
        bluetoothManager.moveToSitting()
        timerManager.updatePosition(.sitting)
    }

    func moveToStandingWithTimer() {
        bluetoothManager.moveToStanding()
        timerManager.updatePosition(.standing)
    }

    func startAutoMoveSequence() {
        // Reset countdown
        autoMoveCountdown = 5

        // Play warning sound
        NSSound.beep()

        // Step 1: Pre-move the desk a few inches as warning
        if autoMoveTargetPosition == .standing {
            // Nudge desk up 2-3 inches
            nudgeDeskUp()
        } else if autoMoveTargetPosition == .sitting {
            // Nudge desk down 2-3 inches
            nudgeDeskDown()
        }

        // Step 2: Start countdown timer
        autoMoveCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if autoMoveCountdown > 0 {
                autoMoveCountdown -= 1

                // Play beep every second
                NSSound.beep()
            } else {
                // Countdown complete, move to full position
                timer.invalidate()
                showingAutoMoveWarning = false

                // Move to target position
                switch autoMoveTargetPosition {
                case .standing:
                    bluetoothManager.moveToStanding()
                    timerManager.updatePosition(.standing)
                case .sitting:
                    bluetoothManager.moveToSitting()
                    timerManager.updatePosition(.sitting)
                case .unknown:
                    break
                }
            }
        }
    }

    func cancelAutoMoveSequence() {
        autoMoveCountdownTimer?.invalidate()
        autoMoveCountdownTimer = nil
    }

    func nudgeDeskUp() {
        // Press raise button briefly (500ms) to move desk up 2-3 inches
        bluetoothManager.pressRaise()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.bluetoothManager.stopMovement()
        }
    }

    func nudgeDeskDown() {
        // Press lower button briefly (500ms) to move desk down 2-3 inches
        bluetoothManager.pressLower()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.bluetoothManager.stopMovement()
        }
    }
}

// MARK: - Desk Scanner View

struct DeskScannerView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Available Desks")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            if bluetoothManager.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning for desks...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bluetoothManager.discoveredDesks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No desks found")
                        .font(.headline)
                    Text("Make sure your desk is powered on and nearby")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(bluetoothManager.discoveredDesks) { desk in
                            DeskRow(desk: desk) {
                                bluetoothManager.connect(to: desk)
                                isPresented = false
                            }
                        }
                    }
                    .padding()
                }
            }

            // Scan Button
            Button(action: {
                if bluetoothManager.isScanning {
                    bluetoothManager.stopScanning()
                } else {
                    bluetoothManager.startScanning()
                }
            }) {
                HStack {
                    Image(systemName: bluetoothManager.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                    Text(bluetoothManager.isScanning ? "Stop Scanning" : "Start Scanning")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(bluetoothManager.isScanning ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            bluetoothManager.startScanning()
        }
    }
}

// MARK: - Desk Row

struct DeskRow: View {
    let desk: UpliftDesk
    let onConnect: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(desk.name)
                    .font(.headline)

                Text("Signal: \(signalStrength)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Connect") {
                onConnect()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var signalStrength: String {
        if desk.rssi > -50 {
            return "Excellent"
        } else if desk.rssi > -70 {
            return "Good"
        } else if desk.rssi > -85 {
            return "Fair"
        } else {
            return "Weak"
        }
    }
}

#Preview {
    ContentView()
}
