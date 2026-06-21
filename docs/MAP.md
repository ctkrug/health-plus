# HealthSync — Repository Map

> **Auto-generated orientation map.** Regenerate with the `/map-repo` skill after structural
> changes. Prose architecture lives in [CLAUDE.md](../CLAUDE.md); this file is the *structural*
> companion — file tree, per-file purpose, the key symbols in each file, and how they wire together.
> Last generated: 2026-06-21.

---

## 1. The 30-second model

SwiftUI iOS 17+ health aggregator. One `@Observable` **`AppState`** owns six services and is
injected app-wide via `.environment()`. Four tabs render off those services. Three **pure engines**
(`InsightsEngine`, `ProgressionEngine`, `SupersetEngine`) hold all the domain logic/thresholds — no
business rules live in views.

```
HealthAggregatorApp (@main)
  └─ AppState (@Observable)                 ← single source of truth, injected everywhere
       ├─ HealthKitService   ── Apple Health read/write
       ├─ WhoopService       ── WHOOP OAuth2 + API
       ├─ WorkoutStore       ── Core Data (programmatic model)
       ├─ HabitStore         ── UserDefaults JSON
       ├─ NotificationService── local notifications
       └─ AuthService        ── Sign in with Apple
  └─ RootView → MainTabView: Today · Workout · Body · Habits
       (Profile + Settings = avatar/card on Today, no longer a tab)
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

  Workout flow   ──▶ WorkoutStore.suggestion(...) ──▶ ProgressionEngine (pure) ──▶ ProgressionSuggestion
  Superset pairing ─▶ SupersetEngine.compatibility / .recommendations (pure) ──▶ SupersetPair / quality + warning
  Habits AI chat ──▶ HabitSetupChatView ──▶ ClaudeService.send(...) [chat] then .runTool(...) [extract] ──▶ HabitStore
  External scales/apps (Renpho/MFP/Swim.com) ──▶ Apple Health ──▶ HealthKitService.refresh()
```

**Rule of thumb for "where does X live":**
| You want to change… | Go to |
|---|---|
| A coaching number / threshold | `Services/InsightsEngine.swift` **+** `docs/SCIENCE.md` (always both) |
| Strength progression math | `Services/ProgressionEngine.swift` |
| Superset pairing logic / warnings | `Services/SupersetEngine.swift` |
| What HealthKit reads/writes | `Services/HealthKitService.swift` |
| WHOOP OAuth / API shape | `Services/WhoopService.swift` + `Models/WhoopModels.swift` |
| A dashboard tile | `Views/Dashboard/Cards/*` |
| Profile / all settings / rest-timer default | `Views/Profile/ProfileView.swift` |
| Colors / cards / rings / fonts / `AppHeader` | `Design/DesignSystem.swift` |
| Tab structure | `App/RootView.swift` |
| Bundle IDs / capabilities | `project.yml` (+ entitlements, Info.plist) — see CLAUDE.md |

---

## 3. File index (by area)

### App/ — entry point & composition root
| File | Key symbols | Purpose |
|---|---|---|
| `App/HealthAggregatorApp.swift` | `HealthAggregatorApp` (@main App), **`AppState`** (@Observable) | Boot, scene, owns all six services + `isOnboardingComplete`. |
| `App/RootView.swift` | `RootView`, `MainTabView` | Onboarding gate → 4-tab `TabView` (Today · Workout · Body · Habits). |

### Design/ — design system (import before building any view)
| File | Key symbols | Purpose |
|---|---|---|
| `Design/DesignSystem.swift` | `Color.accent*`, `.card()`, `RingView`, `SparklineView`, `SectionHeader`, `AppHeader<Trailing>` | All shared visual primitives. Dark-mode only. `AppHeader` has a `trailing` slot (Today uses it for the profile avatar). |
| `Design/HapticsManager.swift` | `HapticsManager` | Haptic feedback wrapper. |

### Services/ — logic & integrations (all owned by AppState)
| File | Key symbols | Purpose |
|---|---|---|
| `Services/HealthKitService.swift` | `HealthKitService` · `requestAuthorization()` `refresh()` `performBackgroundSync()` `writeWorkout(_:)` `addWater(ml:)` | Apple Health read/write. ⚠️ HealthKit ObjC-exception gotchas — see CLAUDE.md before touching units. |
| `Services/WhoopService.swift` | `WhoopService` · `startOAuthFlow(presenting:)` `handleCallback(url:)` `refreshIfNeeded()` `disconnect()`; `WhoopError` | WHOOP OAuth2 (ASWebAuthenticationSession), token refresh, recovery/sleep/cycle fetch. |
| `Services/WorkoutStore.swift` | `WorkoutStore` · `startWorkout(from:)` `completeWorkout(_:)` `deleteSession` `updateSession` `previewSession(for:)` `begin(_:)` `saveProgram` `advanceActiveProgram()` `suggestion(for:rule:)` `isPR(...)` `weeklyVolume(...)` `sessionsThisWeek()` `resetToUserWorkouts()` | Core Data store (model built programmatically, JSON-blob-in-entity). Persists `currentSession` draft to the App Group for crash recovery. Delegates progression to `ProgressionEngine`. |
| `Services/ProgressionEngine.swift` | `ProgressionEngine` (final class) · `suggestion(for:rule:history:)` `populateSession(...)` · `SwimProgressionSuggestion` | **Pure** strength/swim progression. repRange now steps reps +2/session toward max, then adds weight. (`.deload` case defined, never emitted.) |
| `Services/SupersetEngine.swift` | `SupersetEngine` (enum) · `recommendations(for:limit:)` `classify(_:)` `classify(name:)` `compatibility(a:b:)` · `MovementPattern` `SupersetPair` `PairQuality` `SupersetCompatibility` | **Pure** antagonist-superset pairing. Scores pairs (antagonist/partial/non-competing) + emits a warning for same-muscle pairs. See `docs/SCIENCE.md` §10. |
| `Services/InsightsEngine.swift` | `InsightsEngine` (enum) · `bodyInsights` `bodyFat` `muscle` `vo2Max` `cardioVolume` `steps` `proteinTarget` `sleep` `recoveryGuidance` | **Pure** science-backed coaching. Every fn cites `docs/SCIENCE.md`. No thresholds anywhere else. |
| `Services/HabitStore.swift` | `HabitStore` · `toggle(_:slot:on:)` `streak(for:slot:)` `todaySlots()` `addHabit` `applyAIHabits(_:)` | UserDefaults-JSON habit tracking, streaks, milestones. |
| `Services/ClaudeService.swift` | `ClaudeService` · `send(system:history:userMessage:)` [chat] `runTool(model:...)` [forced tool-use extract]; `ClaudeMessage/Request/Response`, `ClaudeError` | Anthropic client for the Habits setup chat. Two-phase: haiku chat → sonnet `save_habits` tool extraction. User's own key. |
| `Services/NotificationService.swift` | `NotificationService` · `scheduleRestTimer` `scheduleDailySummary` `scheduleWeeklyRecap` `scheduleWorkoutReminder` `sendPRNotification` | Local notifications. |
| `Services/AuthService.swift` | `AuthService` · `signInWithApple(...)` `continueAsGuest()` `signOut()` `checkCredentialState()` `updateDisplayName(_:)` | Sign in with Apple + guest mode. Name is editable from Profile. |
| `Services/KeychainService.swift` | `KeychainService` (enum) · `.Key` | Keychain wrapper (WHOOP tokens). Bundle-ID-coupled — see CLAUDE.md. |

### Models/ — Codable domain types
| File | Key symbols |
|---|---|
| `Models/WorkoutModels.swift` | `WorkoutSession` `WorkoutExercise`(+`supersetGroupID`,`progressionRule`) `WorkoutSet` `WorkoutTemplate` `TemplateExercise`(+`supersetGroupID`,`derivedProgressionRule`) `PersonalRecord`; `WorkoutType` `WeightUnit` `DistanceUnit` `StrokeType` |
| `Models/TrainingProgram.swift` | `TrainingProgram` `ProgramWorkout` `ProgramExercise` `ProgressionRule`(+`progressionKg`) `ProgressionSuggestion` `SwimSet`; `ProgressionStrategy` `ProgramGoal` `Equipment` |
| `Models/ExerciseLibrary.swift` | `ExerciseDefinition` `ExerciseLibrary`; `ExerciseCategory` |
| `Models/HabitModels.swift` | `Habit` `HabitLog` `PresetHabit` `HabitLibrary` `ChatMessage`; `HabitCategory` `HabitTimeSlot` `HabitMilestone` |
| `Models/HabitSetupParser.swift` | `HabitSetupParser` (`inputSchema`, `buildHabits(from:)`, `parseHabits(from:)`) — AI habit tool schema + mapping |
| `Models/WhoopModels.swift` | `WhoopRecovery` `WhoopSleep` `WhoopCycle` `WhoopSnapshot` `WhoopTokenResponse` (+ nested `*Score` types) |
| `Models/HealthInsights.swift` | **`UserMetrics`** (+ `.build(hk:whoop:store:)`) `MetricInsight` `RecoveryGuidance` `MetricRating` |
| `Models/MetricCatalog.swift` | `MetricSeries` `MetricCatalog.all(hk:whoop:)` — drives the unified `MetricDetailView` |

### Views/ — SwiftUI, grouped by tab
| Folder | Files | Tab |
|---|---|---|
| `Views/Dashboard/` | `DashboardView` (+ `ProfileSummaryCard`, header avatar → ProfileView) + `Cards/{ActivityRings,BodySnapshot,Nutrition,Recovery,Sleep,Steps,TodayWorkout}Card` | **Today** (home + profile/settings entry) |
| `Views/Workout/` | `WorkoutListView` `ActiveWorkoutView`(in-workout superset pairing, bg-safe timers, finish confirm, rest default) `ProgramView` `TemplateEditorView`(superset pairing) `WorkoutCompleteView` `WorkoutHistoryView`(edit/delete/export/save-as-template) | **Workout** |
| `Views/Body/` | `BodyCompositionView` (all-stats hub: recovery ring + HRV/RHR/Sleep/Strain `MetricTile`s + guidance **merged from old Recovery tab**, then body comp + targets + charts) | **Body** |
| `Views/Habits/` | `HabitsView` `AddHabitView` `HabitLibraryView` `HabitSetupChatView` | **Habits** |
| `Views/Profile/` | `ProfileView` (profile header + **all settings** + rest-timer default), `ProfileAvatar`, `IntegrationRow` | sheet from Today (replaces old Settings tab/sheet) |
| `Views/Insights/` | `InsightComponents` (`InsightsCard` `InsightRow` `RecoveryGuidanceCard`) | shared (Body) |
| `Views/Recovery/` | `MetricDetailView` (unified metric trend page, opened via `MetricNavLink`) | shared (not a tab) |
| `Views/Components/` | `InteractiveTrendChart` (hold-and-drag scrubber) | shared |
| `Views/Onboarding/` | `OnboardingView` `WhoopConnectView` | first-run |
| `Views/Nutrition/` | `NutritionView` | ⚠️ **orphaned** — not in tab bar; nutrition surfaces via dashboard card |

### Other targets & infra
| Path | Purpose |
|---|---|
| `HealthAggregatorWidgets/` | Widget extension. **Can't import app code** — `WorkoutActivityAttributes` + `Color(hex:)` duplicated; keep in sync. |
| `LiveActivity/WorkoutLiveActivity.swift` | Live Activity for active workouts. |
| `scripts/` | `release.sh` `preflight.sh` `test.sh` `testflight-status.sh` `crashlogs.sh` `setup-asc.sh` — ship/diagnose pipeline. |
| `docs/SCIENCE.md` | ⭐ source of truth for every coaching threshold (paired with `InsightsEngine`); §10 covers supersets. |
| `project.yml` | XcodeGen spec — the `.xcodeproj` is generated, never hand-edited. |

---

## 4. Gotchas a model must know before editing
- **HealthKit raises uncatchable ObjC exceptions** — never `HKUnit(from:)` for compound units; always guard `doubleValue(for:)`. Full rules in CLAUDE.md.
- **Thresholds are mirrored**: change a number in `InsightsEngine` (or a superset rule in `SupersetEngine`) → update `docs/SCIENCE.md`.
- **No `.pbxproj` editing** — run `xcodegen generate` after adding/removing files (preflight does it).
- **Bundle IDs are interlinked** across `project.yml`, both `.entitlements`, `Info.plist`, `KeychainService`, and every `UserDefaults(suiteName:)`. Grep, don't assume one constant.
- **Widget target duplicates** `Color(hex:)` + `WorkoutActivityAttributes` intentionally.
- **In-workout state is crash-safe**: `WorkoutStore` mirrors `currentSession` to the App Group (`activeSessionDraft`) and restores it on launch — don't break that round-trip.
- **Supersets** are expressed by a shared `supersetGroupID` UUID on two exercises (both `TemplateExercise` and `WorkoutExercise`).
- **Rest-timer default** is `@AppStorage("defaultRestSeconds")` (set in ProfileView, read in ActiveWorkoutView); superset transitions still use a fixed 20s.
- `NutritionView` is orphaned; `ProgressionEngine.deload` is dead.
