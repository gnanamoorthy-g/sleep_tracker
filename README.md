# Sleep & HRV Tracker

A 24/7 autonomous HRV (Heart Rate Variability) monitoring iOS app that connects to Bluetooth heart rate monitors to track sleep quality, recovery status, and stress levels.

## Features

### Measurement Modes

| Mode | Duration | Frequency | Purpose |
|------|----------|-----------|---------|
| **Continuous** | 24/7 | Always active | Background monitoring, automatic sleep detection |
| **Morning Readiness** | 3 min | Once per day | Daily recovery assessment |
| **Quick Snapshot** | 2 min | On-demand | Pre/post workout, stress checks |

### Core Capabilities

- **Auto-Connect**: Remembers last paired device and auto-reconnects on launch
- **Automatic Sleep Detection**: Detects sleep onset/offset based on HR and HRV patterns
- **Real-Time Stress Monitoring**: Alerts when HRV drops significantly below baseline
- **Recovery Intelligence**: Analyzes trends to provide recovery recommendations
- **Sleep Scoring**: Comprehensive sleep quality scoring based on duration, deep sleep, HRV, and continuity

### HRV Metrics

- **RMSSD**: Root Mean Square of Successive Differences (primary HRV metric)
- **SDNN**: Standard Deviation of NN intervals
- **pNN50**: Percentage of successive intervals differing by >50ms
- **7-day & 30-day Baselines**: Rolling averages for trend comparison

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MainTabView                               │
├────────────┬────────────┬────────────┬──────────────────────────┤
│  Home Tab  │ Monitor Tab│ History Tab│     Settings Tab         │
│ (Dashboard)│ (Live HRV) │ (Sessions) │   (Device/Prefs)         │
└────────────┴────────────┴────────────┴──────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │  AppCoordinator   │
                    │  (Shared State)   │
                    └─────────┬─────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   BLEManager          SleepDetection         StressMonitor
   (Auto-reconnect)    Engine                 (Real-time)
```

## Project Structure

```
Sources/
├── App/
│   └── SleepTrackerApp.swift
├── Core/
│   ├── BLE/                    # Bluetooth connectivity
│   ├── HRV/                    # HRV computation engine
│   ├── Analytics/              # Baseline calculations
│   ├── SleepProcessing/        # Sleep stage inference
│   └── Storage/                # Data buffering
├── Domain/
│   ├── Measurement/            # Session coordination
│   ├── Sleep/                  # Sleep detection
│   ├── Monitoring/             # Stress monitoring
│   └── Intelligence/           # Recovery analysis
├── Data/
│   ├── Models/                 # Data models
│   └── Repositories/           # Data persistence
├── Presentation/
│   ├── Navigation/             # Tab navigation
│   ├── Views/                  # SwiftUI views
│   ├── ViewModels/             # View models
│   └── Trends/                 # Trend visualizations
└── Infrastructure/             # Notifications, background tasks
```

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Bluetooth heart rate monitor with HR and RR interval support

## Getting Started

1. Clone the repository
2. Open `SleepTracker.xcodeproj` in Xcode
3. Build and run on a physical device (BLE requires real hardware)
4. Pair with a compatible heart rate monitor

## Data Storage

All data is stored locally on-device using JSON files:

- **Sleep Sessions**: Complete overnight recordings with epoch data
- **HRV Snapshots**: 2-3 minute readings with context tags
- **Continuous Data**: Hourly aggregations of 24/7 monitoring
- **Daily Summaries**: Aggregated daily statistics
- **Stress Events**: Detected stress episodes with timestamps

## License

Private project - All rights reserved
