📱 Project: Sleep & HRV Tracker (Production Architecture)
🎯 Objective

Build a production-ready iOS app that:

Connects to BLE HR monitor (180D / 2A37)

Extracts RR intervals correctly

Runs in background overnight

Stores long sessions reliably

Computes HRV (RMSSD first)

Is modular, testable, scalable

🏗 High-Level Architecture

Use Clean Architecture + MVVM + Service Layer

App
 ├── Presentation (SwiftUI Views + ViewModels)
 ├── Domain (Business Logic / Use Cases)
 ├── Data (Repositories / Persistence)
 ├── Core (BLE, Parsing, Analytics Engine)
 └── Infrastructure (Logging, Background Tasks)

🗂 Module Breakdown
1️⃣ Core Layer

Low-level hardware + computation logic.

1.1 BLE Module
Files
Core/BLE/
 ├── BLEManager.swift
 ├── BLEPeripheral.swift
 ├── BLEConstants.swift
 ├── BLEError.swift

Responsibilities

Manage CBCentralManager

Scan for 180D

Connect & reconnect

Discover services

Subscribe to 2A37

Stream raw data via Combine publisher

Requirements

Auto reconnect

State restoration enabled

Background Bluetooth mode supported

Thread-safe

1.2 Heart Rate Parser
Core/Parsing/
 ├── HeartRateParser.swift
 ├── HeartRatePacket.swift

Responsibilities

Parse flag byte

Detect 8-bit vs 16-bit HR

Extract RR intervals

Convert to milliseconds

Return typed model:

struct HeartRatePacket {
    let heartRate: Int
    let rrIntervals: [Double]
    let timestamp: Date
}


No BLE code here — pure parsing logic.

1.3 HRV Engine
Core/HRV/
 ├── HRVEngine.swift
 ├── HRVMetrics.swift

Responsibilities

Maintain rolling RR buffer

Compute:

RMSSD

SDNN (future)

pNN50 (future)

Provide sliding window analytics

Example:

func computeRMSSD(from rr: [Double]) -> Double


Engine must be:

Stateless OR state-contained

Unit testable

2️⃣ Domain Layer

Business logic / app use cases.

2.1 Use Cases
Domain/UseCases/
 ├── StartSessionUseCase.swift
 ├── StopSessionUseCase.swift
 ├── ProcessHeartRatePacketUseCase.swift
 ├── ComputeSleepPhaseUseCase.swift

Responsibilities

Start/stop sleep recording

Feed packets into HRV engine

Trigger sleep state inference

2.2 Sleep Inference Engine
Domain/Sleep/
 ├── SleepPhase.swift
 ├── SleepInferenceEngine.swift

Phase 1 Heuristic

HR ↓ + RMSSD ↑ → sleep onset

Stable HR + high RMSSD → deep sleep

HR spike + low RMSSD → disturbance

Return:

enum SleepPhase {
    case awake
    case light
    case deep
}


Keep replaceable for future ML model.

3️⃣ Data Layer

Responsible for storage & retrieval.

3.1 Models
Data/Models/
 ├── SleepSession.swift
 ├── HRVSample.swift


Example:

struct HRVSample: Codable {
    let timestamp: Date
    let heartRate: Int
    let rrIntervals: [Double]
    let rmssd: Double?
}

3.2 Repository Pattern
Data/Repositories/
 ├── SleepSessionRepository.swift


Responsibilities:

Save session

Load sessions

Delete session

3.3 Persistence Strategy
Phase 1

Local JSON files

Phase 2

CoreData

Phase 3

CloudKit sync

4️⃣ Presentation Layer (SwiftUI + MVVM)
4.1 ViewModels
Presentation/ViewModels/
 ├── LiveMonitoringViewModel.swift
 ├── SessionSummaryViewModel.swift


Responsibilities:

Subscribe to BLE publisher

Update UI

Handle session lifecycle

Expose formatted metrics

4.2 Views
Presentation/Views/
 ├── LiveMonitoringView.swift
 ├── SessionSummaryView.swift
 ├── SleepGraphView.swift


Live screen displays:

HR

Latest RR

RMSSD

Sleep phase

Connection status

5️⃣ Infrastructure Layer
5.1 Logging
Infrastructure/
 ├── Logger.swift


Use os.Logger.

Log:

BLE events

Packet parsing

Errors

5.2 Background Support

Requirements:

Enable Background Modes → Bluetooth

State restoration identifier

Handle willRestoreState

Test overnight stability.

6️⃣ Concurrency Model

Use:

Combine OR async/await

MainActor for UI updates

Dedicated queue for BLE parsing

Never block BLE callback thread.

7️⃣ Error Handling Strategy

Define:

enum BLEError: Error {
    case bluetoothUnavailable
    case deviceNotFound
    case connectionFailed
}


UI must reflect:

Disconnected

Reconnecting

Connected

8️⃣ Testing Strategy
Unit Tests

HeartRateParser

HRVEngine (RMSSD accuracy)

SleepInferenceEngine

Integration Tests

Simulated BLE packet injection

Session recording lifecycle

9️⃣ Security & Performance

No health data leaves device

Avoid memory growth during long sessions

Cap RR buffer (e.g., last 10 minutes)

🔟 Roadmap Phases
Phase 1 (Core Functionality)

BLE connect

Parse RR

Display HR + RMSSD

Phase 2 (Session Recording)

Save sessions

Summary screen

Phase 3 (Sleep Tracking)

Sleep inference

Graphs

Overnight background test

Phase 4 (Advanced)

HRV trend analytics

Sleep scoring

Cloud backup