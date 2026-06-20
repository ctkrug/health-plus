# HealthSync (Health+) — Project Guide

iOS health-aggregator app. SwiftUI, iOS 17+, `@Observable` state. Aggregates Apple Health,
WHOOP, and manual workout/habit tracking into one dark-themed dashboard.

GitHub: https://github.com/ctkrug/health-plus

**At the start of any non-trivial task, read [`docs/MAP.md`](docs/MAP.md) first** for orientation —
it's the structural repo map (ownership tree, data-flow graph, per-file symbol index, "where to
change X → go to Y"). Regenerate it with the `/map-repo` skill after structural changes. For live
symbol navigation (find references, symbol overviews), the **Serena** MCP server is configured for
this repo.

---

## ⚡️ Releasing (read this first)

**POLICY: after any major update, ship it to TestFlight — don't just push to GitHub.**
Run the release script, which pushes to GitHub *and* uploads to TestFlight in one shot:

```bash
./scripts/release.sh "short description"           # patch: 1.0.0 → 1.0.1 (default — bug fixes)
./scripts/release.sh --minor "short description"   # minor: 1.0.0 → 1.1.0 (new features)
./scripts/release.sh --major "short description"   # major: 1.0.0 → 2.0.0 (breaking / landmark)
```

(One-time prerequisite: `./scripts/setup-asc.sh` to store the App Store Connect API key.
Until that's done, release.sh still builds + pushes + produces an .ipa, but the final upload
must be finished manually in Transporter/Xcode Organizer.)

This runs the full pipeline:
1. **Preflight** — type-checks both targets + regenerates the Xcode project (aborts on any error).
2. **Bumps the build number** (`CURRENT_PROJECT_VERSION` in `project.yml`) — TestFlight requires a unique build each upload.
3. **Commits & pushes** to `origin/main` with your message.
4. **Archives** (Release, generic iOS device).
5. **Uploads to TestFlight** via the App Store Connect API.

To only validate without shipping:

```bash
./scripts/preflight.sh
```

### One-time setup for automated TestFlight upload
Step 5 needs an App Store Connect API key. Without it, the script still does steps 1–4 and
produces a `.ipa` for manual upload (Xcode Organizer / Transporter).

1. App Store Connect → **Users and Access → Integrations → App Store Connect API** → generate a key (App Manager role).
2. Download the `.p8` **once** to `~/.appstoreconnect/private_keys/`.
3. `cp scripts/.env.example scripts/.env` and fill in `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`.
   (`scripts/.env` is git-ignored.)

### After the first upload of a new version
In App Store Connect → TestFlight → the build → **Manage Compliance → No encryption**
(the app already declares `ITSAppUsesNonExemptEncryption=false`, so this should be automatic).

---

## Crashes & TestFlight feedback (routine)

After a release, check for crashes and tester feedback:

```bash
./scripts/testflight-status.sh
```

This uses the App Store Connect API key to print recent builds + their processing state, plus
**TestFlight tester feedback and crash submissions** (the comment testers type in the in-app popup,
their device/OS, etc.). It pulled the real "App crashes after connecting to health app" report that
caught the VO₂max bug. Run it whenever a build is out or a tester reports something.

For a **symbolicated stack trace** of a specific crash:
```bash
./scripts/crashlogs.sh /path/to/HealthAggregator-….ips   # grab the .ips from the phone or AirDrop
./scripts/crashlogs.sh                                     # or pull from a USB device (needs libimobiledevice)
```
Also: **Xcode → Window → Organizer → Crashes** auto-symbolicates (dSYMs are uploaded with each release;
`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`), and **App Store Connect → TestFlight → Feedback** has the
same data in the web UI.

### ⚠️ HealthKit crash gotcha (learned the hard way)
HealthKit raises **Objective-C exceptions** that Swift `try/catch` CANNOT catch — they crash the app.
The usual causes, all of which must be prevented *by construction*:
- **`HKUnit(from:)` with compound strings throws on iOS 26** — any multi-part unit string
  (`"ml/kg/min"`, `"ml/kg*min"`, etc.) raises an uncatchable ObjC exception in iOS 26's unit parser.
  **Never use `HKUnit(from:)` for compound units.** Build them via API only:
  `HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))`.
- **Wrong unit in `doubleValue(for:)`** — incompatible unit also raises an uncatchable ObjC exception.
  Always guard with `quantity.is(compatibleWith: unit)` before calling `doubleValue`. The shared
  helpers `fetchQuantityMostRecent` / `fetchQuantitySum` already do this — never call `doubleValue` raw.
- **`HKStatisticsQuery` with `.cumulativeSum` on a non-cumulative type** (heart rate, body mass, etc.).
  Use `fetchQuantitySum` only for cumulative types; `fetchQuantityMostRecent` (HKSampleQuery) for the rest.
- Mutating `@Observable` service state off the main thread — assign on `MainActor`.

## Fast iteration (no TestFlight)
For day-to-day testing, don't use the release script — just run on a device from Xcode:
open `HealthAggregator/HealthAggregator.xcodeproj`, pick your iPhone, hit **⌘R**.
TestFlight is only for sharing builds with others.

---

## Project facts

| Thing | Value |
|---|---|
| Display name | **HealthSync** (`CFBundleDisplayName`) |
| App Store name | HealthSync: Fitness Dashboard |
| Main bundle ID | `com.ctkrug.healthplus` |
| Widget bundle ID | `com.ctkrug.healthplus.widgets` |
| App Group | `group.com.ctkrug.healthplus` |
| Apple Team ID | `S6FSYG26T8` |
| Deployment target | iOS 17.0 |
| Privacy policy | https://ctkrug.github.io/health-plus/privacy.html (source: `docs/privacy.html`) |

**Bundle IDs are interlinked** — if they ever change, update them in *all* of: `project.yml`,
both `.entitlements`, `Info.plist` (URL types, BG task IDs), `KeychainService.swift`,
and every `UserDefaults(suiteName:)` call. There's no single constant; grep for the old value.

---

## Architecture

- **No `.xcdatamodeld`** — Core Data model is built programmatically in `WorkoutStore.makeModel()`
  using a JSON-blob-in-entity pattern (each entity stores a `jsonData` blob of a Codable struct).
- **No `.pbxproj` editing** — the Xcode project is generated by **XcodeGen** from `project.yml`.
  Always run `xcodegen generate` after adding/removing files (preflight does this for you).
- **State**: `AppState` (`@Observable`) holds all services; injected via `.environment(appState)`.
  Use stored `var` with `didSet` for UserDefaults-backed observable state — a computed property
  bypasses `@Observable` change tracking and won't trigger re-renders.
- **Services** (`Services/`): `HealthKitService`, `WhoopService` (OAuth via ASWebAuthenticationSession),
  `WorkoutStore` (Core Data), `HabitStore` (UserDefaults JSON), `NotificationService`,
  `AuthService` (Sign in with Apple), `ClaudeService` (Anthropic API for habit-setup chat),
  `ProgressionEngine` (workout progression logic, pure functions).
- **Widget target** (`HealthAggregatorWidgets/`) can't import app code — `WorkoutActivityAttributes`
  and the `Color(hex:)` helper are **intentionally duplicated** there. Keep them in sync.
- Tabs (`RootView`): Today (Dashboard) · Workout · Body · Recovery · Habits. Settings is a sheet
  opened from a subtle gear **FAB (bottom-right)** on the Dashboard. `NutritionView` exists but is
  **not** in the tab bar (orphaned; nutrition shows via the dashboard card).
- **Header / chrome convention**: every tab uses `AppHeader` (logo + optional subtitle), `top`
  `safeAreaInset`. **Never put a button in the top-right corner** — primary actions are bottom-right
  FABs (`.fabStyle()`), refresh is pull-to-refresh, secondary actions live in-content.
- **Theming**: all colors are adaptive light/dark tokens in `DesignSystem.swift` (`Color(light:dark:)`).
  Appearance (System/Light/Dark) is a `@AppStorage("appearanceMode")` setting applied via
  `.preferredColorScheme` in `HealthAggregatorApp`. Don't hardcode hex in views; add a token.
- **Metric detail page** (`Views/Recovery/MetricDetailView.swift`): one unified page for inspecting
  any metric over time, with a **metric dropdown** (switch field without leaving) and 1W/30D/90D/1Y.
  Driven by `Models/MetricCatalog.swift` (`MetricSeries` + `MetricCatalog.all(hk:whoop:)`). Open it
  anywhere with `MetricNavLink(metricID:) { … }` (inside a NavigationStack). Charts use the shared
  `Views/Components/InteractiveTrendChart.swift` (hold-and-drag scrubber; press-then-drag so it
  doesn't steal vertical scroll). Histories for the chart come from `HealthKitService` (~365 days).
- **Workout tab** is intentionally minimal: a "TODAY" hero (active program's next workout) + a
  "YOUR WORKOUTS" list of templates; tapping either opens `WorkoutPreviewView` (exercises + last-used
  values) → **Start**. History/Programs/New are secondary buttons. Preview sessions are built without
  starting via `WorkoutStore.previewProgramSession()` / `previewSession(for:)`; `begin(_:)` commits.

---

## Integrations

- **Apple HealthKit** — read + limited write (workouts, water, swim distance). Permissions requested
  in onboarding and re-requested on launch.
- **WHOOP** — OAuth2. Credentials live in `Info.plist` (`WhoopClientID`/`WhoopClientSecret`),
  redirect `healthaggregator://whoop/callback`, scopes include `read:cycles` (note the `s`).
  Tokens stored in Keychain; refreshed 60s before expiry.
- **Claude API** (`ClaudeService`) — key bundled in Info.plist (`AnthropicAPIKey`). Used only for the
  Habits AI setup chat, which is **two-phase by design**:
  1. **Conversation** — `claude-haiku-4-5-20251001`, plain text. The chat model *only* talks; it never
     emits JSON (a chat model asked to switch into "data mode" reliably refuses to, which caused the old
     "say that's everything" loop).
  2. **Extraction** — a separate one-shot pass via `ClaudeService.runTool(...)` (forced tool use,
     `tool_choice` pinned to `save_habits`) on `claude-sonnet-4-6`. Output is constrained to the tool's
     `input_schema` (defined in `HabitSetupParser.inputSchema`), so it's guaranteed-valid structure —
     no fenced-JSON guessing. Triggered deterministically by the **Done button** or a local end-intent
     phrase (`looksLikeDone`), never by the model deciding it's finished.
     **Gotcha:** forced tool use returns 400 *"conversation must end with a user message"* if the
     messages array ends on an assistant turn (which it does when the user taps Done right after the
     coach's question). So the extraction passes the whole chat as a **single user-role message**
     (a formatted `User:/Coach:` transcript), never the replayed multi-turn history.
  `HabitSetupParser.buildHabits(from:)` maps the tool input → `[Habit]`; the legacy text path
  (`parseHabits(from:)` + `sanitizedReply`) is kept only as a belt-and-braces fallback.
- **Renpho / MyFitnessPal / Swim.com** — no direct API; they sync into Apple Health, and the app
  reads from there. Settings shows setup instructions for each.

---

## Validation commands

Type-check app target only (fast, no project needed):
```bash
cd HealthAggregator
xcrun --sdk iphoneos swiftc -target arm64-apple-ios17.0 -parse-as-library -typecheck \
  $(find HealthAggregator -name "*.swift" | grep -v Widgets | tr '\n' ' ') 2>&1 | grep "error:"
```
SourceKit "cannot find type X in scope" diagnostics during single-file edits are **noise**
(cross-file symbols don't resolve in isolation). Trust the full type-check above / preflight.

---

## Automated regression tests

There is a real XCTest suite (`HealthAggregatorTests/`, a unit-test target hosted in the app).
Run it before any release and whenever you touch logic:

```bash
./scripts/test.sh                # auto-picks the newest available iPhone simulator
./scripts/test.sh "iPhone 17"    # or pin a simulator by name
```

It regenerates the project, boots a simulator, and runs every test. Non-zero exit on any failure
(so it can gate a release). Results land in `HealthAggregator/build/TestResults.xcresult`.

**What's covered** (think of these as the "don't regress" contract):
- `ProgressionEngineTests` — every progression strategy (double/linear/repRange/RPE), first-time,
  session population, Epley 1RM.
- `InsightsEngineTests` — all science thresholds (body fat by sex, FFMI, VO₂max FRIEND norms, steps,
  sleep, cardio, protein, recovery guidance bands). **If a number changes, update `docs/SCIENCE.md`.**
- `WhoopDecodingTests` — WHOOP JSON decoding incl. the **calibration null-score** regression
  (null recovery fields must decode to nil, not throw).
- `HabitStoreTests` — toggle/complete, streaks (gaps, missing-today anchor), milestones (first-time
  fires once), all-time counts, CRUD, dayKey format.
- `ModelCodableTests` — round-trips every persisted model (Habit, WorkoutSession, TrainingProgram,
  WhoopSnapshot, …); a broken Codable would silently drop user data.
- `HabitLibraryTests` — preset integrity (valid hex/icon), category metadata, `libraryOrder` covers
  every non-custom category, milestone copy exists for every count.
- `WorkoutStoreTests` — seed invariants (exactly one active program), PR detection, program cycling.
- `AppConfigTests` — validates the **built** Info.plist (display name, bundle ID, WHOOP keys, URL
  scheme, BG task IDs, that `$(ANTHROPIC_API_KEY)` was actually substituted) + an `AppState` boot
  smoke test. Hosted in the app so `Bundle.main` is the real app bundle.

To add coverage: drop a new `*Tests.swift` in `HealthAggregatorTests/` and re-run (xcodegen picks it
up automatically — no project edits needed). Tests use `@testable import HealthAggregator`; pure
logic lives in engines/stores specifically so it's testable without the UI.

---

## Personalized insights engine (science-backed coaching)

The app gives trainer-style, personalized targets and recommendations. Everything is centralized and
documented:

- **`Services/InsightsEngine.swift`** — pure functions (body fat, FFMI/muscle, VO₂max, cardio volume,
  steps, protein, sleep, recovery guidance). No thresholds anywhere else. Each function cites the
  section of `docs/SCIENCE.md` it implements.
- **`Models/HealthInsights.swift`** — the `UserMetrics` snapshot + `UserMetrics.build(hk:whoop:store:)`
  factory, plus `MetricInsight` / `RecoveryGuidance` / `MetricRating` types.
- **`docs/SCIENCE.md`** — ⭐ the source of truth: every threshold with a cited reference (ACSM, FRIEND
  registry VO₂max norms, Kouri FFMI, Aragon/Helms muscle-gain rates, Paluch steps, Morton protein,
  WHOOP recovery bands, etc.). **When you change a number in code, update the matching section here.**
- **UI:** `Views/Insights/InsightComponents.swift` (`InsightsCard`, `InsightRow`, `RecoveryGuidanceCard`).
  Surfaced on the **Body** tab ("Your Targets" + protein) and **Recovery** tab (training guidance).
- **Profile inputs** (biological sex, age, height, VO₂max, weekly exercise minutes) are read from
  HealthKit in `HealthKitService`. The engine degrades gracefully when any are missing.

To tune the coaching logic: edit thresholds in `InsightsEngine.swift` + update `docs/SCIENCE.md`.
To add a new insight: add a function to the engine, a `MetricInsight` it returns, and include it in
the relevant aggregator (`bodyInsights`) or view.

## Known limitations / future work
- Weight unit (lb/kg) setting is respected in the **workout logging** flow; history/summary
  displays still render in lb.
- Renpho-only metrics (visceral fat, body water, skeletal muscle) show "—" — standard HealthKit
  doesn't expose them.
- `ProgressionEngine` has a `.deload` action case that is defined but never emitted.
- Direct client-side Claude API calls use the user's own key (fine for a personal app; not a
  shared-backend design).

---

## Conventions
- Commit messages end with the `Co-Authored-By: Claude Opus 4.8` trailer (release.sh adds it).
- Don't commit `scripts/.env`, `*.p8`, or `build/` (all git-ignored).
- Dark mode only (`UIUserInterfaceStyle = Dark`, `.preferredColorScheme(.dark)`).
- Colors/fonts/shared components live in `Design/DesignSystem.swift` (`Color.accent*`,
  `.card()`, `RingView`, `SparklineView`, `SectionHeader`, etc.).
