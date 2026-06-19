# HealthSync — Repository Map

> **Auto-generated orientation map.** Regenerate with the `/map-repo` skill after structural
> changes. Prose architecture lives in [CLAUDE.md](../CLAUDE.md); this file is the *structural*
> companion — file tree, per-file purpose, the key symbols in each file, and how they wire together.
> Last generated: 2026-06-19.

---

## 1. The 30-second model

SwiftUI iOS 17+ health aggregator. One `@Observable` **`AppState`** owns six services and is
injected app-wide via `.environment()`. Five tabs render off those services. Two **pure engines**
(`InsightsEngine`, `ProgressionEngine`) hold all the domain logic/thresholds — no business rules
live in views.

```
HealthAggregatorApp (@main)
  └─ AppState (@Observable)                 ← single source of truth, injected everywhere
       ├─ HealthKitService   ── Apple Health read/write
       ├─ WhoopService       ── WHOOP OAuth2 + API
       ├─ WorkoutStore       ── Core Data (programmatic model)
       ├─ HabitStore         ── UserDefaults JSON
       ├─ NotificationService── local notifications
       └─ AuthService        ── Sign in with Apple
  └─ RootView → MainTabView: Today · Workout · Body · Recovery · Habits
```

## 2. Data-flow / dependency graph (where to look for what)

```
Views ──read──▶ AppState.<service>  ──▶ Models (Codable structs)
  │                                          ▲
  │                                          │
  └─ Insights UI ──▶ UserMetrics.build(hk:whoop:store:) ──▶ InsightsEngine (pure) ──▶ MetricInsight
                                                                  │ cites
                                                                  ▼
                                                            docs/SCIENCE.md  (source of truth for every threshold)

  Workout flow ──▶ WorkoutStore.suggestion(...) ──▶ ProgressionEngine (pure) ──▶ ProgressionSuggestion
  Habits AI chat ─▶ HabitSetupChatView ──▶ ClaudeService.send(...) ──▶ HabitStore.applyAIHabits(...)
  External scales/apps (Renpho/MFP/Swim.com) ──▶ Apple Health ──▶ HealthKitService.refresh()
```

**Rule of thumb for "where does X live":**
| You want to change… | Go to |
|---|---|
| A coaching number / threshold | `Services/InsightsEngine.swift` **+** `docs/SCIENCE.md` (always both) |
| Strength progression math | `Services/ProgressionEngine.swift` |
| What HealthKit reads/writes | `Services/HealthKitService.swift` |
| WHOOP OAuth / API shape | `Services/WhoopService.swift` + `Models/WhoopModels.swift` |
| A dashboard tile | `Views/Dashboard/Cards/*` |
| Colors / cards / rings / fonts | `Design/DesignSystem.swift` |
| Tab structure | `App/RootView.swift` |
| Bundle IDs / capabilities | `project.yml` (+ entitlements, Info.plist) — see CLAUDE.md |

---

## 3. File index (by area)

### App/ — entry point & composition root
| File | Key symbols | Purpose |
|---|---|---|
| `App/HealthAggregatorApp.swift` | `HealthAggregatorApp` (@main App), **`AppState`** (@Observable) | Boot, scene, owns all six services + `isOnboardingComplete`. |
| `App/RootView.swift` | `RootView`, `MainTabView` | Onboarding gate → 5-tab `TabView`. |

### Design/ — design system (import before building any view)
| File | Key symbols | Purpose |
|---|---|---|
| `Design/DesignSystem.swift` | `Color.accent*`, `.card()`, `RingView`, `SparklineView`, `SectionHeader` | All shared visual primitives. Dark-mode only. |
| `Design/HapticsManager.swift` | `HapticsManager` | Haptic feedback wrapper. |

### Services/ — logic & integrations (all owned by AppState)
| File | Key symbols | Purpose |
|---|---|---|
| `Services/HealthKitService.swift` | `HealthKitService` · `requestAuthorization()` `refresh()` `performBackgroundSync()` `writeWorkout(_:)` `addWater(ml:)` | Apple Health read/write. ⚠️ HealthKit ObjC-exception gotchas — see CLAUDE.md before touching units. |
| `Services/WhoopService.swift` | `WhoopService` · `startOAuthFlow(presenting:)` `handleCallback(url:)` `refreshIfNeeded()` `disconnect()`; `WhoopError` | WHOOP OAuth2 (ASWebAuthenticationSession), token refresh, recovery/sleep/cycle fetch. |
| `Services/WorkoutStore.swift` | `WorkoutStore` · `startWorkout(from:)` `completeWorkout(_:)` `saveProgram(_:)` `advanceActiveProgram()` `suggestion(for:rule:)` `isPR(...)` `weeklyVolume(...)` | Core Data store (model built programmatically, JSON-blob-in-entity). Delegates progression to `ProgressionEngine`. |
| `Services/ProgressionEngine.swift` | `ProgressionEngine` (final class) · `SwimProgressionSuggestion` | **Pure** strength/swim progression logic. (`.deload` case defined, never emitted.) |
| `Services/InsightsEngine.swift` | `InsightsEngine` (enum) · `bodyInsights` `bodyFat` `muscle` `vo2Max` `cardioVolume` `steps` `proteinTarget` `sleep` `recoveryGuidance` | **Pure** science-backed coaching. Every fn cites `docs/SCIENCE.md`. No thresholds anywhere else. |
| `Services/HabitStore.swift` | `HabitStore` · `toggle(_:slot:on:)` `streak(for:slot:)` `todaySlots()` `addHabit` `applyAIHabits(_:)` | UserDefaults-JSON habit tracking, streaks, milestones. |
| `Services/ClaudeService.swift` | `ClaudeService.send(system:history:userMessage:)`; `ClaudeMessage/Request/Response`, `ClaudeError` | Anthropic API client for the Habits setup chat only. User's own key. Model: `claude-haiku-4-5-20251001`. |
| `Services/NotificationService.swift` | `NotificationService` · `scheduleRestTimer` `scheduleDailySummary` `scheduleWorkoutReminder` `sendPRNotification` | Local notifications. |
| `Services/AuthService.swift` | `AuthService` · `signInWithApple(...)` `continueAsGuest()` `signOut()` `checkCredentialState()` | Sign in with Apple + guest mode. |
| `Services/KeychainService.swift` | `KeychainService` (enum) · `.Key` | Keychain wrapper (WHOOP tokens). Bundle-ID-coupled — see CLAUDE.md. |

### Models/ — Codable domain types
| File | Key symbols |
|---|---|
| `Models/WorkoutModels.swift` | `WorkoutSession` `WorkoutExercise` `WorkoutSet` `WorkoutTemplate` `PersonalRecord`; `WorkoutType` `WeightUnit` `DistanceUnit` `StrokeType` |
| `Models/TrainingProgram.swift` | `TrainingProgram` `ProgramWorkout` `ProgramExercise` `ProgressionRule` `ProgressionSuggestion` `SwimSet`; `ProgressionStrategy` `ProgramGoal` `Equipment` |
| `Models/ExerciseLibrary.swift` | `ExerciseDefinition` `ExerciseLibrary`; `ExerciseCategory` |
| `Models/HabitModels.swift` | `Habit` `HabitLog` `PresetHabit` `HabitLibrary` `ChatMessage`; `HabitCategory` `HabitTimeSlot` `HabitMilestone` |
| `Models/WhoopModels.swift` | `WhoopRecovery` `WhoopSleep` `WhoopCycle` `WhoopSnapshot` `WhoopTokenResponse` (+ nested `*Score` types) |
| `Models/HealthInsights.swift` | **`UserMetrics`** (+ `.build(hk:whoop:store:)`) `MetricInsight` `RecoveryGuidance` `MetricRating` |

### Views/ — SwiftUI, grouped by tab
| Folder | Files | Tab |
|---|---|---|
| `Views/Dashboard/` | `DashboardView` + `Cards/{ActivityRings,BodySnapshot,Nutrition,Recovery,Sleep,Steps,TodayWorkout}Card` | **Today** |
| `Views/Workout/` | `WorkoutListView` `ActiveWorkoutView` `ProgramView` `WorkoutCompleteView` `WorkoutHistoryView` | **Workout** |
| `Views/Body/` | `BodyCompositionView` | **Body** (+ Insights "Your Targets") |
| `Views/Recovery/` | `RecoveryView` `MetricDetailView` | **Recovery** |
| `Views/Habits/` | `HabitsView` `AddHabitView` `HabitLibraryView` `HabitSetupChatView` | **Habits** |
| `Views/Insights/` | `InsightComponents` (`InsightsCard` `InsightRow` `RecoveryGuidanceCard`) | shared (Body + Recovery) |
| `Views/Onboarding/` | `OnboardingView` `WhoopConnectView` | first-run |
| `Views/Settings/` | `SettingsView` | gear sheet from Dashboard |
| `Views/Nutrition/` | `NutritionView` | ⚠️ **orphaned** — not in tab bar; nutrition surfaces via dashboard card |

### Other targets & infra
| Path | Purpose |
|---|---|
| `HealthAggregatorWidgets/` | Widget extension. **Can't import app code** — `WorkoutActivityAttributes` + `Color(hex:)` duplicated; keep in sync. |
| `LiveActivity/WorkoutLiveActivity.swift` | Live Activity for active workouts. |
| `scripts/` | `release.sh` `preflight.sh` `testflight-status.sh` `crashlogs.sh` `setup-asc.sh` — ship/diagnose pipeline. |
| `docs/SCIENCE.md` | ⭐ source of truth for every coaching threshold (paired with `InsightsEngine`). |
| `project.yml` | XcodeGen spec — the `.xcodeproj` is generated, never hand-edited. |

---

## 4. Gotchas a model must know before editing
- **HealthKit raises uncatchable ObjC exceptions** — never `HKUnit(from:)` for compound units; always guard `doubleValue(for:)`. Full rules in CLAUDE.md.
- **Thresholds are mirrored**: change a number in `InsightsEngine` → update `docs/SCIENCE.md`.
- **No `.pbxproj` editing** — run `xcodegen generate` after adding/removing files (preflight does it).
- **Bundle IDs are interlinked** across `project.yml`, both `.entitlements`, `Info.plist`, `KeychainService`, and every `UserDefaults(suiteName:)`. Grep, don't assume one constant.
- **Widget target duplicates** `Color(hex:)` + `WorkoutActivityAttributes` intentionally.
- `NutritionView` is orphaned; `ProgressionEngine.deload` is dead.
