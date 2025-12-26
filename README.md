# Uplift Desk Controller

Control your Uplift standing desk from macOS with smart reminders to help you maintain a healthy sit-stand routine.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.0+-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Desk Control** - One-tap presets for sitting/standing, manual height adjustment
- **Smart Reminders** - Configurable intervals to alternate positions
- **Daily Goals** - Track and achieve your standing time goals
- **Working Hours** - Only get reminders during work hours
- **Auto-Move** - Optionally move desk automatically with safety countdown
- **Auto-Connect** - Automatically connects to your last used desk

## Quick Start

1. Open `uplift-desk-automated.xcodeproj` in Xcode
2. Build and run (⌘R)
3. Click "Connect to Desk"
4. Start using your desk!

## Setup

### Requirements
- macOS 12.0+
- Bluetooth-enabled Mac
- Uplift desk with Bluetooth

### First Time Use
1. Grant Bluetooth and Notification permissions when prompted
2. Connect to your desk via the scanner
3. Configure reminders in Settings (⚙️ icon)

## Usage

### Basic Control
- **Sitting/Standing buttons** - Quick presets
- **Raise/Lower buttons** - Manual adjustment
- **Height display** - Real-time height in inches

### Timer System
1. Open Settings and enable "Enable Position Timer"
2. Set your daily standing goal (e.g., 4 hours)
3. Set reminder interval (e.g., 30 minutes)
4. Optional: Enable working hours (e.g., 9 AM - 5 PM)
5. Optional: Enable auto-move for automatic desk adjustment

### Presets
- **Office Worker** - 4h standing, 30min intervals
- **Moderate** - 2h standing, 45min intervals
- **Beginner** - 1h standing, 60min intervals

## Troubleshooting

**Desk not found?**
- Check Bluetooth is enabled
- Ensure desk is powered on
- Move Mac closer to desk

**Connection fails?**
- Disconnect other devices from desk
- Restart the app

**Reminders not working?**
- Check timer is enabled in Settings
- Verify notification permissions
- Check working hours settings

## Technical

### BLE Protocol
- Service: `FE60`
- Control: `FE61` (commands)
- Height: `FE62` (notifications)

### Commands
| Action | Byte |
|--------|------|
| Wake | `0x00` |
| Raise | `0x01` |
| Lower | `0x02` |
| Sit | `0x05` |
| Stand | `0x06` |

## Project Structure

```
uplift-desk-automated/
├── ContentView.swift          # Main UI
├── SettingsView.swift         # Settings
├── BluetoothManager.swift     # BLE communication
├── DeskTimerManager.swift     # Timers & reminders
├── TimerSettings.swift        # Settings model
└── UpliftDesk.swift          # Desk model
```

## License

MIT License

---

**Built with SwiftUI and CoreBluetooth**
