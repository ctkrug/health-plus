# Health+ — App Specification & Developer README

**Last updated:** June 2026  
**Platform:** iOS 17+  
**Language:** Swift 5.9 · SwiftUI · Swift Observation framework  
**Xcode project generator:** XcodeGen (`project.yml`)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [File Structure](#file-structure)
4. [Data Models](#data-models)
5. [Services](#services)
6. [Views — Tab by Tab](#views)
7. [Workout System — Deep Dive](#workout-system)
8. [Design System](#design-system)
9. [Integrations](#integrations)
10. [Notifications & Background Tasks](#notifications--background-tasks)
11. [Persistence](#persistence)
12. [Setup & Build Instructions](#setup--build-instructions)
13. [Known Limitations & Future Work](#known-limitations--future-work)

---

## Overview

Health+ is a personal health aggregator and smart workout coach for iOS. It pulls data from Apple HealthKit, WHOOP, Renpho (via HealthKit), and MyFitnessPal (via HealthKit), then surfaces everything in one dark-mode dashboard. The workout module doubles as a personal trainer: it tracks progressive overload across strength and swim sessions, auto-populates sets from history, prescribes A/B/C programs, and surfaces one-tap progression suggestions after each session.

### Core Capabilities

| Area | What it does |
|---|---|
| Dashboard | 7 rearrangeable cards: steps, sleep, recovery, body snapshot, nutrition, activity rings, today's workout |
| Workout | Log sets in real time, timer, PR detection, program tracking, progression coaching |
| Body Composition | Weight, body fat %, BMI trend charts from HealthKit/Renpho |
| Recovery | WHOOP recovery score, HRV, resting HR, sleep stages |
| Nutrition | Calories, protein, carbs, fat from HealthKit/MFP |
| Settings | WHOOP OAuth, nutrition goals, reminder time, weight unit |

---

## Architecture

```
HealthAggregatorApp  (entry point, @main)
└── AppState  (@Observable singleton injected via .environment)
    ├── HealthKitService
    ├── WhoopService
    ├── WorkoutStore
    └── NotificationService
```

### Key Patterns

- **iOS 17 Observation** — `@Observable` macro everywhere. Views use `@Environment(AppState.self)` and `@State`; no `ObservableObject`, no `@StateObject`, no `@EnvironmentObject`.
- **Pure SwiftUI** — no UIKit wrappers except `ASWebAuthenticationSession` (WHOOP OAuth).
- **Core Data** — programmatic model (no `.xcdatamodeld`); JSON-blob storage for complex nested types; 4 entities (see Persistence section).
- **XcodeGen** — `project.yml` at repo root generates the `.xcodeproj`. Run `xcodegen generate` after adding/removing Swift files.
- **Swift Charts** — used for body composition and nutrition trend charts.

---

## File Structure

```
HealthAggregator/
├── App/
│   ├── HealthAggregatorApp.swift   — @main, AppState, background task registration
│   └── RootView.swift              — Onboarding gate, MainTabView
├── Design/
│   ├── DesignSystem.swift          — Color palette, fonts, card modifier, extensions
│   └── HapticsManager.swift        — UIImpactFeedbackGenerator wrappers
├── LiveActivity/
│   └── WorkoutLiveActivity.swift   — Dynamic Island / Lock Screen workout activity
├── Models/
│   ├── WorkoutModels.swift         — WorkoutSession, WorkoutExercise, WorkoutSet, WorkoutTemplate
│   ├── TrainingProgram.swift       — Equipment, ProgressionRule/Strategy/Suggestion, TrainingProgram, ProgramWorkout, ProgramExercise, SwimSet
│   ├── ExerciseLibrary.swift       — 60+ exercises, built-in programs, defaultTemplates
│   └── WhoopModels.swift           — WHOOP API response types
├── Services/
│   ├── HealthKitService.swift      — HK authorization, read 20 types, write workouts + swim laps
│   ├── WhoopService.swift          — OAuth 2.0 + token refresh, REST API client
│   ├── WorkoutStore.swift          — Core Data CRUD, program management, PR detection, streak
│   ├── ProgressionEngine.swift     — Progression algorithm, session population, coach messages
│   ├── NotificationService.swift   — Rest timer, daily summary, weekly recap, workout reminder
│   └── KeychainService.swift       — WHOOP token storage
└── Views/
    ├── Dashboard/
    │   ├── DashboardView.swift     — Rearrangeable card grid (@AppStorage order)
    │   └── Cards/
    │       ├── TodayWorkoutCard.swift
    │       ├── StepsCard.swift
    │       ├── SleepCard.swift
    │       ├── RecoveryCard.swift
    │       ├── BodySnapshotCard.swift
    │       ├── NutritionCard.swift
    │       └── ActivityRingsCard.swift
    ├── Workout/
    │   ├── WorkoutListView.swift   — Workout hub: active program, history, start options
    │   ├── ActiveWorkoutView.swift — Live session: sets, timer, progression badges, PR crowns
    │   ├── ProgramView.swift       — Program list, active program card, program detail
    │   ├── WorkoutCompleteView.swift — Post-workout summary, PRs, volume
    │   └── WorkoutHistoryView.swift — Filterable past sessions
    ├── Body/
    │   └── BodyCompositionView.swift
    ├── Recovery/
    │   └── RecoveryView.swift
    ├── Nutrition/
    │   └── NutritionView.swift
    ├── Settings/
    │   └── SettingsView.swift
    └── Onboarding/
        ├── OnboardingView.swift
        └── WhoopConnectView.swift
```

---

## Data Models

### WorkoutModels.swift

```swift
struct WorkoutSession: Identifiable, Codable, Equatable
struct WorkoutExercise: Identifiable, Codable, Equatable
struct WorkoutSet: Identifiable, Codable, Equatable {
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Int?    // for timed sets
    var distanceMeters: Double?  // for swim sets
    var strokeType: String?
    var isWarmup: Bool = false
    var isPR: Bool = false       // set by WorkoutStore.detectPRs()
    var estimated1RM: Double?    // Epley formula, computed, guards r ∈ (0,36]
}
struct WorkoutTemplate: Identifiable, Codable
```

`WorkoutSet.estimated1RM` uses the Epley formula: `weight × (1 + reps/30)`.  
`isPR` is set by `WorkoutStore.detectPRs(in:)` before saving, comparing estimated1RM against all prior sessions for that exercise.

### TrainingProgram.swift

```swift
enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, machine, cable, bodyweight,
         kettlebell, band, ezBar, trapBar, smithMachine
    var defaultProgressionKg: Double  // barbell: 2.268 (5 lb), dumbbell: 2.268, machine: 4.536 (10 lb)
}

enum ProgressionStrategy: String, Codable {
    case doubleProgression   // increase reps first, then weight
    case linearWeight        // add fixed weight each session
    case repRange            // work within a rep range, advance when top reached
}

struct ProgressionRule: Codable {
    var strategy: ProgressionStrategy
    var minReps: Int
    var maxReps: Int
    var weightIncrementKg: Double
    var setsRequired: Int          // sets that must hit maxReps before advancing weight
}

struct ProgressionSuggestion {
    enum Action { case increaseWeight(by: Double), increaseReps, holdSteady, deload, firstTime }
    var action: Action
    var suggestedWeightKg: Double?
    var suggestedReps: Int?
    var coachMessage: String
}

struct TrainingProgram: Identifiable, Codable {
    var workouts: [ProgramWorkout]
    var currentIndex: Int          // which workout is next
    var isActive: Bool
    func advance()                 // increments currentIndex % workouts.count
    var nextWorkout: ProgramWorkout?
    var nextWorkoutLabel: String   // "Workout A", "Workout B", etc.
}

struct ProgramWorkout: Identifiable, Codable {
    var exercises: [ProgramExercise]
    func toWorkoutSession() -> WorkoutSession
}

struct ProgramExercise: Identifiable, Codable {
    var exerciseName: String
    var equipment: Equipment
    var rule: ProgressionRule
    var targetSets: Int
    var isSwim: Bool
    var swimDistance: Double?
    var swimStroke: String?
}
```

### ExerciseLibrary.swift

**60+ exercises** organized by category (Chest, Back, Shoulders, Arms, Legs, Core, Swim, Cardio). Each carries:
- Equipment tag(s)
- `defaultRule: ProgressionRule` based on category (strength uses double progression; swim uses rep-range)

**Built-in Programs:**
| Program | Structure |
|---|---|
| `strongerABC` | 3-day A/B/C full-body barbell program |
| `pplProgram` | Push/Pull/Legs 3-day split |
| `upperLowerProgram` | Upper/Lower 2-day split |
| `swimProgram` | 3-day swim program with yardage progression |

`ExerciseLibrary.defaultTemplates` — computed from the first 2 built-in programs, used to seed Core Data on first launch.

---

## Services

### WorkoutStore.swift

Primary store for all workout data. Backed by Core Data.

**Key properties:**
```swift
@Observable final class WorkoutStore {
    var sessions: [WorkoutSession]            // all completed sessions, newest first
    var templates: [WorkoutTemplate]          // user-created + seeded templates
    var programs: [TrainingProgram]           // all programs
    var currentSession: WorkoutSession?       // live in-progress session (shown in banner)
    var activeProgram: TrainingProgram?       // computed: first program where isActive == true
}
```

**Key methods:**
```swift
func startSession(from template: WorkoutTemplate? = nil) -> WorkoutSession
func startProgramWorkout() -> WorkoutSession   // pre-populated from active program's next workout
func completeWorkout(_ session: WorkoutSession, fromProgram: Bool = false)
    // → detectPRs(in: &session)
    // → saves to Core Data
    // → writes to HealthKit
    // → if fromProgram: advanceActiveProgram()
    // → fires PR push notifications
func saveProgram(_ program: TrainingProgram)
func deleteProgram(_ program: TrainingProgram)
func setActiveProgram(_ program: TrainingProgram)
func advanceActiveProgram()                   // increments currentIndex on active program
func sessionsThisWeek() -> [WorkoutSession]   // uses Calendar.dateInterval(of: .weekOfYear)
var streak: (current: Int, longest: Int)      // deduplicates same-day sessions
```

**PR Detection** (`detectPRs(in session: inout WorkoutSession)`):  
For each set with a computable 1RM, compares against all prior sessions for the same exercise name. If higher, sets `workoutSet.isPR = true`. Called before saving so the persisted JSON contains PR flags.

**Seeding** (`seedDefaultTemplates`):  
Called once on first launch. Captures `ExerciseLibrary.defaultTemplates` into a `let` so in-memory and disk UUIDs match.

### ProgressionEngine.swift

Stateless engine — all functions are pure given inputs.

```swift
final class ProgressionEngine {
    // Main entry point
    func suggestion(for exercise: ProgramExercise, rule: ProgressionRule, history: [WorkoutSession]) -> ProgressionSuggestion

    // Pre-populate a session with smart weights from history
    func populateSession(programWorkout: ProgramWorkout, history: [WorkoutSession]) -> WorkoutSession

    // Weekly coach summary text
    var weeklyCoachSummary: String   // uses exact week boundary via dateInterval(of: .weekOfYear)
}
```

**Progression Strategies:**

| Strategy | Logic |
|---|---|
| `doubleProgression` | If all working sets hit `maxReps`, add `weightIncrementKg` next session. Otherwise suggest same weight, aim for more reps. |
| `linearWeight` | Add `weightIncrementKg` every session unconditionally. |
| `repRange` | If top of range hit, add weight. If bottom of range not reached, deload 10%. |
| Swim | If all intervals completed at target distance, increase by 25m next session. |

**Coach messages** — randomized from a pool per action type (increase/hold/deload/first time).

### HealthKitService.swift

Reads 20 HK quantity/category types including:
- Steps, heart rate, HRV, resting HR
- Body weight, body fat % (`.percent()` returns 0–1 fraction, stored as-is)
- Sleep (category type), active/resting calories
- Swim distance, swim stroke count
- Nutrition macros (calories, protein, carbs, fat)

Writes:
- `HKWorkout` (strength + swim) with samples
- Swim laps (`HKQuantityType.strokeCount`, `HKQuantityType.distanceSwimming`)
- `writeTypes` includes `.distanceSwimming` to avoid runtime auth errors for swim sessions

**Background sync:** `performBackgroundSync()` — called by `BGProcessingTask`, refreshes all read values.

### WhoopService.swift

WHOOP REST API client with full OAuth 2.0 flow.

```swift
@Observable final class WhoopService {
    var isConnected: Bool
    var latestRecovery: WhoopRecovery?
    var latestSleep: WhoopSleep?
    var cycles: [WhoopCycle]

    func connect()     // launches ASWebAuthenticationSession (strong ref: authSession property)
    func disconnect()
    func refreshIfNeeded()
    private func get<T: Decodable>(path: String, retried: Bool = false) async throws -> T
        // On 401: refreshes token once (retried guard prevents infinite recursion)
}
```

Tokens stored in Keychain via `KeychainService`. Callback URL scheme: `healthaggregator://whoop/callback`.

### NotificationService.swift

```swift
@Observable final class NotificationService {
    var isAuthorized: Bool

    func requestAuthorization() async
    func scheduleRestTimer(seconds: Int)   // cancels existing before scheduling
    func cancelRestTimer()
    func scheduleDailySummary()            // 7 PM daily
    func updateDailySummaryContent(steps:recovery:calories:)
    func scheduleWeeklyRecap()             // Sunday 9 AM
    func scheduleWorkoutReminder(hour: Int, minute: Int)  // cancels existing first
    func cancelWorkoutReminder()
    func sendPRNotification(exerciseName: String, weight: Double, reps: Int)
}
```

Notifications only scheduled after `isAuthorized == true` (checked in `RootView.task`).

---

## Views

### Dashboard (`DashboardView`)

7 cards in a scrollable VStack. Order persisted to `@AppStorage("dashboardCardOrder")` as JSON-encoded `[DashboardCard]` (both `Codable`). User can drag to reorder (`.onMove`).

| Card | Data source |
|---|---|
| TodayWorkoutCard | `WorkoutStore.sessions.first` |
| StepsCard | `HealthKitService.steps` |
| SleepCard | `HealthKitService.sleepHours` |
| RecoveryCard | `WhoopService.latestRecovery` |
| BodySnapshotCard | `HealthKitService.bodyWeight`, `bodyFat` |
| NutritionCard | `HealthKitService` macros |
| ActivityRingsCard | `HealthKitService` active/resting cal, exercise minutes |

`TodayWorkoutCard` label reads "Today's Workout" if last session was today, "Last Workout" otherwise.

### Workout Hub (`WorkoutListView`)

Top section: active program card (if any) with "YOUR PROGRAM" header and "Start [Workout X]" button.  
Below: recent sessions list, "All Programs" navigation, "New Workout" FAB.

Sheets: `ProgramView`, `ActiveWorkoutView` (from program start), `WorkoutHistoryView`.

### Active Workout (`ActiveWorkoutView`)

State machine for a live session:
- Pre-populated sets from program history (via `ProgressionEngine.populateSession`)
- Per-set `SetRow` with weight/reps text fields; `onAppear` only initializes if empty (prevents LazyVStack scroll clobber)
- Per-exercise `ProgressionBadge` — shows coach message + "Apply" button; colors: green (increase), blue (hold), yellow (deload)
- Rest timer: tap set → starts countdown → fires local notification when done; `startTimer()` guarded against duplicate timers
- Equipment badge per exercise
- PR crown (👑) on sets where `isPR == true`
- `.onChange(of: session)` syncs live session back to `store.currentSession` so the banner stays fresh
- `finishWorkout()` detects `fromProgram` by checking if first exercise matches active program's next workout exercises; passes flag to `completeWorkout`

### Programs (`ProgramView`)

- Active program card at top with current workout label and "Start Workout" button
- List of all programs (built-in + user-created)
- `ProgramDetailView` — expandable workout cards showing all exercises, sets/reps targets, equipment
- `NewProgramView` — create custom programs
- Sheet-hosted: has its own `@State private var activeSession` so "Start Workout" works without parent view access

### Body Composition (`BodyCompositionView`)

Swift Charts line charts for weight and body fat % over selectable time windows (1W / 1M / 3M / 1Y).

### Recovery (`RecoveryView`)

WHOOP recovery score ring, HRV trend, resting HR, sleep score. Falls back gracefully when WHOOP is not connected.

### Nutrition (`NutritionView`)

Macro breakdown from HealthKit. Progress bars for calories and protein vs. goals. Goals set in Settings and persisted via `@AppStorage`.

### Settings (`SettingsView`)

- **Integrations:** WHOOP (OAuth connect/manage), Renpho / MFP / Swim.com (instructions to enable HealthKit sync)
- **Nutrition Goals:** calorie + protein goals (persisted via `@AppStorage`, synced to local `@State` on `.onAppear`)
- **Notifications:** workout reminder toggle + time picker (hour AND minute persisted via `@AppStorage`)
- **Units:** lbs / kg picker (`WeightUnit` enum)
- **About:** version 1.0.0

---

## Workout System — Deep Dive

### Progressive Overload Flow

```
1. User opens WorkoutListView
2. Active program card shown → tap "Start Workout A"
3. ProgramView.startProgramWorkout() →
     WorkoutStore.startProgramWorkout() →
     ProgressionEngine.populateSession(programWorkout:history:)
     → returns WorkoutSession pre-filled with suggested weights
4. ActiveWorkoutView presented as sheet
5. User logs sets, modifies weights/reps as needed
6. Tap "Finish" →
     finishWorkout() detects fromProgram: true
     WorkoutStore.completeWorkout(session, fromProgram: true)
     → detectPRs(in: &session)     marks isPR on sets
     → saves to Core Data
     → writes HKWorkout to HealthKit
     → advanceActiveProgram()      currentIndex increments
     → fires PR notifications
7. Next time user opens program, Workout B is shown
8. ProgressionEngine checks this exercise's history →
     if all sets hit maxReps last session: suggests +5 lbs
     else: suggests same weight, aim for more reps
```

### Equipment & Weight Increments

| Equipment | Default increment |
|---|---|
| Barbell | 2.268 kg (5 lb) |
| Trap bar | 2.268 kg (5 lb) |
| Smith machine | 2.268 kg (5 lb) |
| EZ bar | 2.268 kg (5 lb) |
| Dumbbell | 2.268 kg (5 lb) |
| Machine | 4.536 kg (10 lb) |
| Cable | 2.268 kg (5 lb) |
| Kettlebell | 4 kg |
| Band / Bodyweight | 0 (rep range strategy) |

### Built-in Programs

**Stronger A/B/C** (3-day full-body barbell)
- Workout A: Squat, Bench, Deadlift, OHP, Barbell Row
- Workout B: Squat, OHP, Bench, Deadlift, Chin-up
- Workout C: Squat, Bench, Romanian Deadlift, Barbell Row, Dips

**Push/Pull/Legs**
- Push: Bench, OHP, Dumbbell Lateral Raise, Tricep Pushdown, Incline DB Press
- Pull: Barbell Row, Lat Pulldown, Cable Row, Bicep Curl, Face Pull
- Legs: Squat, Romanian Deadlift, Leg Press, Leg Curl, Calf Raise

**Upper/Lower**
- Upper A: Bench, Barbell Row, OHP, Lat Pulldown, Bicep/Tricep
- Lower A: Squat, Romanian Deadlift, Leg Press, Leg Curl

**Swim Program** (3-day)
- Day 1: 10×100m freestyle
- Day 2: 8×100m backstroke
- Day 3: 6×100m butterfly

---

## Design System

All tokens defined in `DesignSystem.swift`:

### Colors (semantic, dark-mode first)

```swift
Color.appBackground       // #0A0A0F — near-black
Color.cardBackground      // #12121A
Color.cardBorder          // #1E1E2E
Color.textPrimary         // .white
Color.textSecondary       // white @ 60%
Color.textTertiary        // white @ 35%
Color.accentBlue          // #3B82F6
Color.accentGreen         // #22C55E
Color.accentOrange        // #F97316
Color.accentPurple        // #A855F7
Color.accentTeal          // #14B8A6 (defined in DesignSystem; use accentBlue as fallback)
```

### Typography

```swift
Font.metric(_ size: CGFloat)         // tabular numbers, semibold — for data values
Font.metricLabel(_ size: CGFloat)    // caption weight — for data labels
```

### Card Modifier

```swift
extension View {
    func card() -> some View  // cardBackground fill, cardBorder stroke, 16pt corner radius, 16pt padding
}
```

### Haptics

```swift
HapticsManager.shared.impact(.light / .medium / .heavy / .rigid / .soft)
HapticsManager.shared.notification(.success / .warning / .error)
```

---

## Integrations

### Apple HealthKit

**Read types (20):**
- Activity: stepCount, activeEnergyBurned, basalEnergyBurned, exerciseTime, standTime
- Heart: heartRate, restingHeartRate, heartRateVariabilitySDNN
- Body: bodyMass, bodyFatPercentage, bodyMassIndex, leanBodyMass, height
- Nutrition: dietaryEnergyConsumed, dietaryProtein, dietaryCarbohydrates, dietaryFat
- Sleep: sleepAnalysis (category type)
- Swim: distanceSwimming, swimmingStrokeCount

**Write types:**
- workoutType, activeEnergyBurned, distanceWalkingRunning, distanceSwimming

**Body fat note:** HK `.percent()` returns values in range 0.0–1.0 (e.g., 0.20 = 20%). Do NOT divide by 100.

### WHOOP

OAuth 2.0 authorization code flow:
- Auth URL: `https://api.prod.whoop.com/oauth/oauth2/auth`
- Token URL: `https://api.prod.whoop.com/oauth/oauth2/token`
- Redirect URI: `healthaggregator://whoop/callback`
- Scopes: `offline read:recovery read:sleep read:workout read:profile read:body_measurement`

Token storage: Keychain (access group: `com.healthaggregator.app`).  
Token refresh: automatic on 401, with `retried: Bool` guard to prevent infinite recursion.  
`ASWebAuthenticationSession` retained as a stored property on `WhoopService` to prevent deallocation during OAuth flow.

### Renpho / MyFitnessPal / Swim.com

Read-only via HealthKit. User must enable "Health" sync within each third-party app's settings. No direct API integration.

---

## Notifications & Background Tasks

### Notification Identifiers

| Identifier | Purpose | Schedule |
|---|---|---|
| `rest_timer` | Rest complete between sets | User-triggered, one-shot |
| `daily_summary` | Daily health snapshot | 7:00 PM daily |
| `weekly_recap` | Weekly progress | Sunday 9:00 AM |
| `workout_reminder` | Time to train | User-configured time |
| `pr_<UUID>` | New personal record | Immediate (0.5s delay) |

### Background Tasks

| Identifier | Type | Handler |
|---|---|---|
| `com.healthaggregator.app.whoopRefresh` | `BGAppRefreshTask` | Fetches latest WHOOP data; re-schedules itself every 30 min |
| `com.healthaggregator.app.healthkitSync` | `BGProcessingTask` | Full HK re-sync |

Both use safe `guard let` cast (not force-cast) before handling.  
Both must be declared in `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`.

---

## Persistence

### Core Data Entities (programmatic model — no .xcdatamodeld)

| Entity | Key attributes | Notes |
|---|---|---|
| `WorkoutSessionEntity` | `id: UUID`, `data: Data` | Full `WorkoutSession` JSON blob |
| `PersonalRecordEntity` | `exerciseName: String`, `weightKg: Double`, `reps: Int32`, `date: Date` | Denormalized for fast PR lookup |
| `WorkoutTemplateEntity` | `id: UUID`, `data: Data` | Full `WorkoutTemplate` JSON blob |
| `TrainingProgramEntity` | `id: UUID`, `data: Data`, `isActive: Bool` | Full `TrainingProgram` JSON blob; `isActive` indexed for fast active-program lookup |

### AppStorage Keys

| Key | Type | Used by |
|---|---|---|
| `onboardingComplete` | Bool | `AppState.isOnboardingComplete` |
| `dashboardCardOrder` | Data (JSON) | `DashboardView` |
| `calorieGoal` | Double | `SettingsView`, `NutritionCard` |
| `proteinGoalGrams` | Double | `SettingsView`, `NutritionCard` |
| `workoutReminderEnabled` | Bool | `SettingsView` |
| `workoutReminderHour` | Int | `SettingsView` |
| `workoutReminderMinute` | Int | `SettingsView` |

### Keychain

- WHOOP access token: key `whoop_access_token`
- WHOOP refresh token: key `whoop_refresh_token`

---

## Setup & Build Instructions

### Prerequisites

- **Xcode 15+** (iOS 17 SDK)
- **XcodeGen** — `brew install xcodegen`
- **WHOOP developer account** — register your app at developer.whoop.com for OAuth credentials

### First-Time Setup

```bash
# 1. Clone / open the project folder
cd "Personal Health APp"

# 2. Generate the Xcode project
cd HealthAggregator
xcodegen generate

# 3. Open in Xcode
open HealthAggregator.xcodeproj
```

### WHOOP OAuth Configuration

In `WhoopService.swift`, replace the placeholder constants:
```swift
private let clientId     = "YOUR_WHOOP_CLIENT_ID"
private let clientSecret = "YOUR_WHOOP_CLIENT_SECRET"
```

In Xcode → Target → Info → URL Types, add a URL scheme: `healthaggregator`.

### Info.plist Requirements

Add these keys manually in Xcode (Target → Info):

```xml
<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>Health+ reads your health data to give you a complete picture of your wellbeing.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Health+ saves your workouts to Apple Health.</string>

<!-- Background Tasks -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.healthaggregator.app.whoopRefresh</string>
    <string>com.healthaggregator.app.healthkitSync</string>
</array>

<!-- HealthKit capability must also be enabled in Signing & Capabilities tab -->
```

### Running Type-Check (CI / pre-build sanity)

```bash
xcrun --sdk iphoneos swiftc \
  -target arm64-apple-ios17.0 \
  -parse-as-library \
  -typecheck \
  $(find HealthAggregator -name "*.swift" | grep -v Widgets | tr '\n' ' ')
```

LSP will show many "Cannot find type X in scope" errors — these are false positives from single-file analysis. Only `swiftc -typecheck` with all files simultaneously is authoritative.

### After Adding New Swift Files

Always run `xcodegen generate` before building. The `.xcodeproj` is generated — do not add files directly in Xcode if you want `project.yml` to stay as the source of truth.

---

## Known Limitations & Future Work

### Current Limitations

- **No cloud sync** — all data lives on-device (Core Data + HealthKit). No iCloud backup of workout programs.
- **No widget target** — Widget code is excluded from type-check but the target is not yet fully wired.
- **Live Activity** — `WorkoutLiveActivity.swift` exists but the Dynamic Island / Lock Screen activity is not yet started from `ActiveWorkoutView`.
- **WHOOP webhooks** — currently using polling via BGAppRefreshTask. Webhooks would give real-time updates but require a server.
- **No Apple Watch companion** — rest timer notification is the only cross-device feature.
- **No custom program builder UI** — `NewProgramView` scaffold exists but full exercise picker / drag-to-reorder is not yet implemented.
- **Swim stroke auto-detect** — swim workouts must have stroke type set manually; no HK stroke auto-detection.

### Suggested Enhancements

1. **iCloud CloudKit sync** for workout history and programs across devices
2. **Apple Watch app** — log sets from wrist, trigger rest timer, see progression badge
3. **Live Activity** — wire `WorkoutLiveActivity` to `ActiveWorkoutView` on session start
4. **1RM trend chart** — per-exercise strength progress over time (Swift Charts)
5. **Body weight × rep PR** — current PR detection uses estimated 1RM; could also track max reps at bodyweight separately
6. **Custom program builder** — full exercise picker with search, drag-to-reorder sets
7. **Deload week auto-scheduling** — if no PR in 3 weeks, suggest a deload automatically
8. **Nutrition logging** — currently read-only from MFP; direct barcode scan + food log would replace MFP dependency
9. **Sleep coaching** — correlate WHOOP recovery with sleep data to surface actionable insights
10. **WHOOP Webhooks** — replace 30-min polling with real-time push via webhook + server relay
