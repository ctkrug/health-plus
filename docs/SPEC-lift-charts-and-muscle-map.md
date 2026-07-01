# Spec: Per-Lift Progress Charts + Interactive Muscle Map

> Research/spec only — no implementation yet. Written against the app as of v1.13.0 (build 36).
> Companion to [`docs/MAP.md`](MAP.md) (structure) and [`docs/SCIENCE.md`](SCIENCE.md) (thresholds).

---

## Part 1 — Per-Lift Progress Charts

### 1.1 What exists today that we reuse

The app already has the exact charting pattern this needs, built for HealthKit/WHOOP metrics:

- **`MetricSeries`** (`Models/MetricCatalog.swift`) — `{ id, title, unit, icon, color, current, history: [(Date, Double)], format, showAverage }`.
- **`MetricDetailView`** (`Views/Recovery/MetricDetailView.swift`) — a unified page with a metric-switcher dropdown and a `ChartPeriod` picker (`1W / 30D / 90D / 1Y`), filtering `history` by a cutoff date.
- **`InteractiveTrendChart`** (`Views/Components/InteractiveTrendChart.swift`) — the actual chart: press-and-drag scrubber, lollipop label, optional average line, area fill.
- **`MetricNavLink(metricID:)`** — a link wrapper that opens `MetricDetailView` from anywhere inside a `NavigationStack`.

None of this is HealthKit-specific in shape — `MetricSeries` is just `[(Date, Double)]` + display metadata. A per-lift chart is the same shape with a different data source.

### 1.2 New data source: per-exercise history from `WorkoutStore`

`WorkoutStore` already has `sessions: [WorkoutSession]` and a `weeklyVolume(for exerciseName:, weeks:)` helper, so exercise-name-based lookups are an established pattern. Add a pure aggregation (engine-style, testable, no UI):

```swift
struct LiftDataPoint {
    let date: Date
    let sessionID: UUID
    let topWeightKg: Double      // heaviest completed set that day
    let topReps: Int             // reps at that top set
    let estimated1RM: Double     // Epley — already computed per-set as WorkoutSet.estimated1RM
    let totalVolume: Double      // Σ weight × reps for the exercise that session
    let isPR: Bool
}

enum LiftHistory {
    static func points(for exerciseName: String, in sessions: [WorkoutSession]) -> [LiftDataPoint]
}
```

- Match by exercise name. **Gotcha to spec around:** `WorkoutExercise.name` is a free string — need case-insensitive/trimmed matching, and ideally a canonical exercise identity (see §2.2 — the same normalization problem the muscle map needs, so solve it once, share it).
- One `LiftDataPoint` per **session**, not per set — a lift's "progress" is best read as one point per workout (top set or e1RM that day), not one point per rep set, or the chart gets noisy with 3–5 points per session clustered on the same date.

### 1.3 What the user picks: which metric, which lift

Three chartable metrics per lift, user-toggleable (segmented control, same visual language as `ChartPeriod`):

| Metric | Formula | Why |
|---|---|---|
| Top weight | heaviest completed set's weight | simplest, matches "how much am I lifting" |
| Estimated 1RM | Epley on the best set (already computed per set) | normalizes across rep ranges — comparable week to week even if rep target changed |
| Session volume | Σ weight × reps for that exercise that day | best proxy for hypertrophy-driven progress, not just strength |

Default to **estimated 1RM** — it's the most stable trend line and already computed (`WorkoutSet.estimated1RM`), no new math.

### 1.4 UI entry points

- **New `LiftDetailView`**, structurally a clone of `MetricDetailView`: exercise picker (searchable, since 60+ exercises) instead of a metric dropdown, same `ChartPeriod` control, same `InteractiveTrendChart`, PR markers overlaid as a distinct dot/star on the line.
- Reached two ways:
  1. From **`WorkoutHistoryView`** — tapping an exercise name in a past session, or a PR card, opens `LiftDetailView` pre-scoped to that exercise (`LiftNavLink(exerciseName:)`, mirrors `MetricNavLink`).
  2. From the **Workout tab** — a new "Progress" entry point (button near the existing "YOUR WORKOUTS" list, not a new tab — see CLAUDE.md's tab-count rule) opens the exercise picker directly.

### 1.5 Edge cases to design for

- **Sparse data**: a lift trained once every 2 weeks will look empty on `1W`/`30D` — reuse the existing "no data" messaging pattern from `MetricSeries.noDataMessage`.
- **Unit changes**: `WeightUnit` (lb/kg) is a known partial-migration issue (per CLAUDE.md, history views still render lb) — the chart must respect the current display-unit setting even though underlying storage is `weightKg`; don't regress the known limitation further.
- **Exercise renamed mid-history** (e.g., "DB Bench" → "Dumbbell Bench Press"): out of scope for v1; note as a known gap, revisit if it comes up.

### 1.6 Testing

Unit tests analogous to `WorkoutStoreTests`/`ProgressionEngineTests`: synthetic `[WorkoutSession]` fixtures → assert `LiftHistory.points` picks the correct top set per session, computes volume correctly, flags the right point as PR, and handles a single-session / zero-session lift gracefully.

### 1.7 Build size

Small. This is almost entirely composition of existing components (`InteractiveTrendChart`, `ChartPeriod`, `MetricNavLink`'s pattern) plus one new pure aggregation function. Good candidate to ship first, independent of Part 2.

---

## Part 2 — Interactive Muscle Map

This is a bigger feature: a body diagram, a scoring engine, a recommendation system, and an educational content layer. Spec'd in pieces so it can be built incrementally.

### 2.1 What exists today

- `ExerciseDefinition` (`Models/ExerciseLibrary.swift`) already has `muscleGroups: [String]` per exercise (e.g. Bench Press → `["Chest", "Triceps", "Front Delts"]`), 60+ exercises across `ExerciseCategory` (chest/back/shoulders/arms/legs/core/cardio/swim/fullBody).
- `SupersetEngine.MovementPattern` (11 cases: `horizontalPush`, `horizontalPull`, `verticalPush`, `verticalPull`, `elbowFlexion`, `elbowExtension`, `kneeDominant`, `hipDominant`, `shoulderAnt`, `shoulderPost`, `calves`, `core`, `other`) already infers movement pattern from an exercise's `muscleGroups` + name, for antagonist-pairing in supersets. It's a *movement-pattern* classifier, not a *muscle-group* one — reusable as a reference implementation for "read `muscleGroups: [String]` and classify," but too coarse for muscle-level balance (it doesn't distinguish biceps from quads, only push/pull/flexion axes).
- `docs/SCIENCE.md` has no muscle-volume or balance section yet — this needs a new `§11`.
- Pure-engine convention is established (`InsightsEngine`, `ProgressionEngine`, `SupersetEngine`): static functions, no UI/IO, every threshold cited in `docs/SCIENCE.md`, unit-tested against fixtures.

### 2.2 Foundational work: a canonical muscle taxonomy

`muscleGroups: [String]` today is free text ("Front Delts", "Lower Back", "Lats", ...). The muscle map needs a closed, computable taxonomy. Proposed ~17-group set (matches the granularity most lifting apps — Strong, Hevy — use, and matches what's already implicit in the library's strings):

```swift
enum MuscleGroup: String, CaseIterable, Codable {
    case chest
    case lats, upperBack, lowerBack, traps
    case frontDelts, sideDelts, rearDelts
    case biceps, triceps, forearms
    case quads, hamstrings, glutes, calves
    case abs, obliques
}
```

**Migration required**: each `ExerciseDefinition` needs `primaryMuscles: [MuscleGroup]` + `secondaryMuscles: [MuscleGroup]` (weighted contribution — see §2.5). Recommend *adding* these fields rather than replacing `muscleGroups: [String]` (which is presumably still used for exercise-editor display text); derive the display string from the canonical set later to remove duplication, but that's a v2 cleanup, not a blocker. Populating ~60 exercises is a data-entry pass, not a design decision — can be done from standard anatomy references once the taxonomy is approved.

**Grouping for diagram rendering** (front view vs. back view — a muscle only needs to render on the side it's visible from):

| Front | Back |
|---|---|
| chest, frontDelts, biceps, forearms, abs, obliques, quads | lats, upperBack, lowerBack, traps, rearDelts, triceps, glutes, hamstrings, calves |
| sideDelts (visible both) | sideDelts (visible both) |

### 2.3 The body diagram — decided

**No hand-drawing, no paid dependency. Decided after two rounds of live research (2026-07-01) into real repos, licenses, and vendor terms — not recalled from memory.** Constraint from you: zero cost. That single constraint resolves most of what was previously an open question.

#### Tier 1 — 2D muscle map (v1, build this)

**Decision: [`melihcolpan/MuscleMap`](https://github.com/melihcolpan/MuscleMap).** Verified directly (fetched the repo, license file, and source): MIT license, 201 stars, 0 open issues, actively maintained (last push 2026-04-20, 9 releases), zero external dependencies, targets iOS 17+/macOS 14+ — an exact match to this app's deployment target. It's not a library you'd need to adapt — it's already the thing:

- Ships its own bundled artwork as native Swift — muscle geometry is SVG path-data parsed by its own `SVGPathParser`/`PathBuilder` into SwiftUI `Path`, rendered via `Canvas`. No runtime SVG-parsing dependency, no separate art license to track (the art is covered by the same MIT license as the code — no external attribution obligation beyond a standard MIT notice).
- **~20–32 named, independently-colorable muscle regions per view** (male/female, front/back, left/right split for most) — confirmed via rendered screenshots as professional-quality anatomical illustration (separated deltoid heads, distinct forearm bundles, segmented abs), not a crude blob diagram.
- **Built-in heatmap gradients** (linear/radial/neon/thermal) — this is directly the highlight-mode mechanism §2.4 needs, already built.
- 11-language localization + VoiceOver accessibility names, UIKit wrapper included — a genuinely finished package, not a toy.
- One real gap to plan around: its bundled muscle groups won't map 1:1 onto the ~17-group taxonomy in §2.2 (e.g., it may combine or split differently than `frontDelts`/`sideDelts`/`rearDelts`) — the taxonomy work in §2.2 needs to be reconciled against `MuscleMap`'s actual region names once it's pulled in, before locking `MuscleGroup`'s cases.

This supersedes the earlier `react-native-body-highlighter` / wger / SVGView comparison — those remain fine fallbacks if `MuscleMap` doesn't hold up under real use, but there's no reason to build a manual SVG-tracing pipeline when a purpose-built, MIT-licensed, native-SwiftUI package already exists and does exactly this.

- Front/back toggle: segmented control above the diagram (matches `MuscleMap`'s own male/female + front/back model).
- Color encoding depends on the active highlight mode (§2.4) — map onto `MuscleMap`'s existing gradient system rather than building parallel color-token infrastructure; extend `DesignSystem.swift` only for whatever it doesn't already cover (e.g. a "no data yet" neutral/hatched state).
- Haptic on tap via `HapticsManager` (already used elsewhere in the app).

Worth restating: a 2D muscle heatmap is not a consolation prize — it's the actual flagship version of this feature in Strong, Hevy, and JEFIT (all gate it behind their Pro tier). `MuscleMap`'s visual quality clears that bar.

#### Tier 2 — 3D anatomy (real, no-cost-viable, but not v1)

BioDigital (native SDK, real tap callbacks) is **ruled out** — its free tier explicitly excludes API/developer access and the paid tiers are sales-gated/undisclosed, which fails the no-cost constraint outright. Visible Body is ruled out (no developer API/SDK exists at all). That leaves one real free path, and a second round of research found it's better than initially scoped:

- **[BodyParts3D](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/download.html)** (DBCLS, Japan) — the original dataset Z-Anatomy is partly built from, but downloadable **standalone**, with no Z-Anatomy dependency. Verified: **CC BY 4.0** (confirmed on the archive's current license page — an upgrade from the CC BY-SA 2.1 figure found in the first research pass; CC BY has **no share-alike/copyleft obligation**, just an attribution string — meaningfully cleaner for a closed-source commercial app). 1,523 individually identified anatomical structures with FMA IDs. Ships an **explicit 99%-polygon-reduction variant** — i.e., a mobile-appropriate low-poly option is offered out of the box, not something to reverse-engineer. Format is OBJ (would need conversion to USDZ for RealityKit — a real but bounded, scriptable step). One real caveat: the downloads are bundled multi-object ZIP archives, not one-file-per-muscle — splitting per named structure is a one-time data-prep script, not blind Blender archaeology (unlike Z-Anatomy, where per-muscle mesh separation was unconfirmed without manually opening the file).
- **Z-Anatomy** stays the fallback if BodyParts3D's structure turns out to be harder to split than expected, but BodyParts3D is now the better first choice: cleaner license (no share-alike), explicit low-poly variant, and no NonCommercial-licensed sub-models to strip out.
- A broader hunt for a more turnkey free 3D muscular model (Sketchfab, TurboSquid free tier, itch.io, Meshy.ai) found nothing better-licensed or better-documented than BodyParts3D.

**Decision: build both, in the same pass.** You confirmed Tier 2 is in scope now *because* BodyParts3D is genuinely free — if it weren't, it'd wait. Since taxonomy/engine work is shared between tiers, sequence Tier 2's data-engineering (mesh extraction, OBJ→USDZ conversion, mobile-perf pass) in parallel with Tier 1's UI build rather than strictly after it — see the revised phasing in §2.10.

### 2.4 Highlight modes — decided

1. **Balance status (default, decided).** Color = under-trained / optimal / over-trained relative to that muscle's volume landmark (§2.5). This is the core ask: "tells you where to focus."
2. **Volume heatmap** — secondary toggle, not default. Color intensity ∝ sets performed in the last 7/14 days, independent of any target.
3. **Freshness/recency** — deferred to v2, not built now (adds a second scoring axis; balance status + volume heatmap cover the v1 ask).

### 2.5 The Balance Index — scoring engine

New pure engine, `Services/MuscleBalanceEngine.swift`, following the `InsightsEngine`/`ProgressionEngine` convention (static functions, cites `docs/SCIENCE.md §11`, unit-tested).

**Step 1 — fractional set-volume per muscle group.** An exercise trains multiple muscles unevenly. Standard approach (used by RP's volume methodology and mirrored in apps like Hevy/Strong): primary movers get full credit per working set, secondary/synergist movers get partial credit (e.g. 0.5×). Example: Bench Press primary=chest, secondary=[triceps, frontDelts] → 1 set of bench = 1.0 set toward chest, 0.5 toward triceps, 0.5 toward front delts.

```swift
static func weeklyVolume(sessions: [WorkoutSession], windowDays: Int = 7) -> [MuscleGroup: Double]
```

**Step 2 — volume landmarks per muscle group (MEV/MAV/MRV).** Renaissance Periodization's weekly-set landmarks (Minimum Effective Volume / Maximum Adaptive Volume / Maximum Recoverable Volume), broadly consistent with Schoenfeld et al.'s dose-response meta-analyses on training volume and hypertrophy, give commonly-cited *ranges* per muscle group per week (approximate, natural lifter, will need a citation-verification pass before going into `docs/SCIENCE.md` at the same rigor as the ACSM/FRIEND-registry citations already there):

| Muscle | MEV (sets/wk) | MRV (sets/wk) |
|---|---|---|
| Chest | 8 | 20 |
| Back (lats+upper back) | 10 | 25 |
| Quads | 8 | 20 |
| Hamstrings | 6 | 16 |
| Glutes | 4 | 16 |
| Shoulders (all 3 delt heads combined) | 6 | 22 |
| Biceps | 6 | 20 |
| Triceps | 6 | 18 |
| Calves | 8 | 20 |
| Abs | 0* | 20 |
| Traps | 4 | 16 |
| Forearms | 0* | 16 |

\* trained substantially as a synergist in compound pulls/carries; a dedicated MEV isn't required to make progress.

**Step 3 — antagonist/agonist ratio checks.** Independent of absolute volume, classic strength-and-conditioning / injury-prevention ratios (widely used in return-to-play and ACL-risk screening, PT literature):

- **Hamstring : Quadriceps** — commonly cited target ≈ 0.6–0.8 conventional strength ratio; quad-dominant imbalance is a known ACL/knee-strain risk factor. **Directly relevant to Charlie's own knee rehab** (per his current 12-Week Build program).
- **Pull : Push volume** (back+rear delts+biceps vs. chest+front delts+triceps) — general guidance targets roughly 1:1 to 1.5:1 pull:push, for shoulder-joint health and posture (chronic push-dominant training is linked to rounded-shoulder posture / impingement risk).
- **Posterior chain (lower back+glutes+hamstrings) : Anterior core (abs+obliques)** — balanced core training is associated with lower low-back-pain risk. **Also directly relevant to Charlie's back rehab.**

These ratio checks should be **surfaced explicitly**, not just folded into the composite score — given the user's known injury history, a dedicated "knee-safety" (H:Q) and "back-safety" (posterior:anterior core) callout is higher-value than a generic balance number.

**Step 4 — minimum sample gate.** Don't score a muscle (or the composite) until there's enough data to mean something: require ≥2 weeks of rolling history AND ≥1 logged working set for that muscle in the current window. Below that, the region renders in a neutral "not enough data yet" state rather than a misleading "under-trained" flag — a fresh account or a muscle nobody's trained yet shouldn't look alarming.

**Step 5 — composite Balance Index (0–100 or letter grade).** Weighted blend of: (a) % of muscle groups at/above MEV in the rolling window, (b) how close the antagonist ratios are to target (penalize deviation), (c) an over-training flag for anything past MRV (informational, not necessarily "bad" during an intentional bulk — Charlie's current program is exactly that).

```swift
struct MuscleBalanceReport {
    let overallScore: Int                       // 0–100, nil-able if globally insufficient data
    let perMuscle: [MuscleGroupBalance]          // status per group
    let antagonistPairs: [AntagonistPairStatus]  // H:Q, pull:push, posterior:anterior core
    let recommendations: [MuscleRecommendation]
}

enum BalanceStatus { case noData, under, optimal, over }

struct MuscleGroupBalance {
    let group: MuscleGroup
    let status: BalanceStatus
    let weeklySets: Double
    let mev: Double
    let mrv: Double
}
```

### 2.6 Recommendations — "where to focus"

Rank muscle groups by: below-MEV first, weighted up if they're also on the losing side of an antagonist ratio (i.e., a muscle that's both under its own MEV *and* dragging down a safety-relevant ratio surfaces first). For each flagged muscle, surface 2–3 concrete exercises from `ExerciseLibrary` where it's a `primaryMuscle`, filtered to equipment the user actually has (existing `Equipment` enum already models this), and preferring exercises not already heavily used that week (variety, reusing whatever "recently used" signal `WorkoutStore` already tracks for template suggestions).

```swift
struct MuscleRecommendation {
    let group: MuscleGroup
    let reason: String                       // "Below target volume" / "Lagging vs. quads — knee-safety ratio"
    let suggestedExercises: [ExerciseDefinition]
}
```

### 2.7 Educational content layer

Static, hand-authored content per `MuscleGroup` — not computed, not science-threshold-grade citation rigor (that rigor is reserved for the volume/ratio numbers above), but should still be accurate and sourced from standard kinesiology/anatomy references:

```swift
struct MuscleInfo {
    let group: MuscleGroup
    let displayName: String            // "Chest"
    let anatomicalName: String?        // "Pectoralis Major"
    let function: String               // plain-English, 1–2 sentences
    let whyItMatters: String           // posture / daily-life / performance relevance
    let synergists: [MuscleGroup]      // muscles that co-contract with it
    let antagonist: MuscleGroup?       // opposing muscle
    let notes: String?                 // e.g. common tightness/injury notes, kept light — not medical advice
}
```

Storage: a static `MuscleLibrary.all: [MuscleGroup: MuscleInfo]`, same shape as `HabitLibrary`'s preset content. ~17 entries to write once; no engine logic, pure content.

### 2.8 UI flow — decided

- **Entry point (decided)**: a "Muscle Balance" card in the **Body tab** (`BodyCompositionView`), alongside the existing Insights/RecoveryGuidance cards — consistent with that tab already being the home for "your targets" style content. Shows a mini score + "View Muscle Map →". No new top-level tab (per CLAUDE.md's tab-count convention).
- **`MuscleMapView`**: front/back toggle, the diagram, the Balance Index headline, a legend, and a "Focus on:" strip (top 2–3 recommendations) below the diagram.
- **`MuscleGroupDetailView`** (tap a region → sheet or push): name + status chip, the `MuscleInfo` educational blurb, this-muscle's weekly-volume trend (small chart, can reuse the Part 1 charting primitives), antagonist-ratio bar if applicable, and the exercise list (tappable — could deep-link into starting/adding to a workout, v2).
- Left/right unilateral tracking: **out of scope for now** (per your call) — no `side` field added to `WorkoutSet`; all volume/balance math stays bilateral-only. Revisit only if it becomes a real ask later.

### 2.8.1 Notification tie-in — decided (build it)

Local notification when a muscle group crosses into a bad imbalance state, following the existing `NotificationService` pattern (`Services/NotificationService.swift`, which already has `sendPRNotification` as the closest precedent — an event-driven, not time-scheduled, local notification).

- **Trigger, not a schedule**: fire from the same weekly-rolling-window recompute the Balance Index already runs (§2.5 Step 4's 2-week gate), not a separate timer. Two conditions, either fires:
  1. A muscle group **newly crosses from `optimal`/`noData` into `under`** on a given recompute (state-change edge, not "is currently under" — prevents re-notifying every day for a muscle that's been under for a week straight).
  2. A muscle group has been `under` for **2+ consecutive weekly evaluations** *and* is the losing side of one of the §2.5 Step 3 safety-relevant antagonist ratios (H:Q, posterior:anterior core) — these get priority phrasing given the knee/back rehab context, e.g. "Hamstrings are lagging behind quads — worth a focus session" rather than a generic volume nudge.
- **Rate-limited by construction**: at most one muscle-imbalance notification per recompute cycle (pick the single worst offender if multiple qualify, don't queue a burst) — reuses the same "don't nag" discipline as the existing PR/reminder notifications.
- New identifier alongside the existing ones (`Services/NotificationService.swift`'s notification-identifier list per `docs/MAP.md`), e.g. `muscleImbalanceAlert`; body copy pulls the muscle's `MuscleInfo.displayName` (§2.7) and the `MuscleRecommendation.reason` (§2.6) so the notification and the in-app "Focus on:" strip say the same thing.
- Respects existing notification-permission handling — no new permission prompt, rides the same authorization the app already requests.

### 2.9 Testing strategy

Mirrors `InsightsEngineTests`/`WorkoutStoreTests`: synthetic session histories → assert fractional-volume aggregation (primary full credit, secondary half credit), assert `BalanceStatus` classification at MEV/MRV boundaries, assert the "not enough data" gate actually gates, assert recommendation ranking order, assert antagonist-ratio math on known fixtures (e.g., a quad-only training history should flag H:Q imbalance).

### 2.10 Phasing (incremental build order) — final

1. **Part 1 (lift charts)** — ships independently, small, mostly composition of existing components.
2. **Pull in `melihcolpan/MuscleMap` (SPM) and reconcile its region names against the §2.2 taxonomy** — do this before finalizing `MuscleGroup`'s cases, since the package's actual muscle-region set is the ground truth now, not an abstract 17-group list.
3. **Muscle taxonomy + data migration** (§2.2, adjusted per step 2) — foundational, no UI, unblocks everything else, shared by both tiers.
4. **`MuscleBalanceEngine`** (§2.5–2.6) — backend only, unit-testable without any UI.
5. **`docs/SCIENCE.md §11`** — write up the volume-landmark and antagonist-ratio citations properly (verify against primary sources, not just the widely-circulated field consensus summarized here).
6. **In parallel from here on:**
   - **Tier 1 diagram + `MuscleMapView`/`MuscleGroupDetailView`** (§2.3, §2.8) — wire `MuscleMap`'s rendering to the balance engine's output, balance-status as default highlight mode. This is the v1 ship target.
   - **Tier 2 data pipeline** (BodyParts3D download → per-muscle mesh extraction → OBJ→USDZ conversion → on-device perf pass) — independent engineering track against the same taxonomy from step 3; doesn't block Tier 1's ship.
   - **Notification tie-in** (§2.8.1) — small addition once the engine (step 4) exists; can land alongside Tier 1.
7. **`MuscleLibrary` educational content** (§2.7) — parallel with step 6 once the taxonomy (step 3) is locked.

### 2.11 Decisions — closed

All prior open questions are resolved:

| Decision | Call |
|---|---|
| Default highlight mode | **Balance status** (§2.4) |
| Nav placement | **Body-tab card** (§2.8) |
| Left/right unilateral tracking | **Out of scope for now** (§2.8) |
| Notification tie-in | **Build it** — event-driven, rate-limited (§2.8.1) |
| Tier 2 (3D) | **Build now, in parallel with Tier 1** — greenlit because BodyParts3D is genuinely free (§2.3); would not have been built now otherwise |

Nothing left blocking implementation start.
