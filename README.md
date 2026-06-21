# HealthSync (Health+)

A personal iOS health aggregator and **smart workout coach**. It pulls Apple Health + WHOOP + manual
tracking into one dark-mode dashboard, logs workouts set-by-set with progressive-overload suggestions and
PR detection, and turns your numbers into science-backed guidance (body-fat bands, FFMI, VO₂max
percentiles, protein targets, recovery readiness).

> Status: **v1.9.0 (build 32)** · iOS 17+ · feature-complete, with a 12-test suite and a TestFlight
> release pipeline.

## Features

- **Today** — a rearrangeable dashboard of your key metrics (steps, sleep, HRV, recovery, weight, more).
- **Workout** — live set-by-set logging with progressive-overload suggestions, PR detection, antagonist
  superset pairing, rest timers, and 4 built-in programs (A/B/C, PPL, Upper/Lower, Swim).
- **Body** — body composition + cardio metrics with cited guidance (body-fat classification, FFMI, VO₂max
  percentile, protein target).
- **Habits** — habit tracking with streaks and an AI-assisted setup chat.
- **Integrations** — Apple **HealthKit** (read ~20 metrics, write workouts/swims), **WHOOP** (OAuth;
  recovery, strain, sleep; 30-min background refresh), and passthrough from Renpho / MyFitnessPal /
  Swim.com via HealthKit.

## Tech

Swift 5.9 · SwiftUI · iOS 17+ (`@Observable`) · Core Data + UserDefaults · Swift Charts · BackgroundTasks ·
ASWebAuthenticationSession (WHOOP) · Sign in with Apple. State flows through a single `@Observable`
`AppState`; all business logic lives in pure engines (`ProgressionEngine`, `InsightsEngine`,
`SupersetEngine`) and services. Built with **XcodeGen** (`project.yml` → `.xcodeproj`).

## Build & run

```bash
brew install xcodegen           # one-time
xcodegen generate               # project.yml -> HealthAggregator.xcodeproj
open HealthAggregator/HealthAggregator.xcodeproj
```

Set your Anthropic API key (for the habit coach) via the `ANTHROPIC_API_KEY` build setting. WHOOP client
credentials live in `Info.plist`.

## Project layout

```
HealthAggregator/
  HealthAggregator/        app source (~13k lines Swift, 62 files)
    App/ Design/ Services/ Models/ Views/{Dashboard,Workout,Body,Habits,Profile}/
  HealthAggregatorTests/   12 unit tests (progression, insights, WHOOP, habits, models, config)
  HealthAggregatorWidgets/ home-screen widgets
docs/
  MAP.md                   structural repo map (read first; regenerate with /map-repo)
  SCIENCE.md               every coaching threshold, with citations
  privacy.html             https://ctkrug.github.io/health-plus/privacy.html
scripts/release.sh         version bump → GitHub push → TestFlight upload
CLAUDE.md                  project guide / conventions / gotchas
SPEC.md                    technical deep-dive
```

## Releasing

```bash
./scripts/release.sh "fix"            # patch
./scripts/release.sh --minor "feat"   # minor
```
Pushes to GitHub *and* uploads to TestFlight in one shot. See `CLAUDE.md` for the full policy.

## Notes

- Coaching thresholds are population reference points (ACE/ACSM, FRIEND VO₂max norms, ISSN protein, WHOOP
  recovery bands), **not medical advice** — see `docs/SCIENCE.md` for sources.
- HealthKit can throw uncatchable ObjC exceptions; guard `doubleValue(for:)` and avoid `HKUnit(from:)` with
  compound strings (see `CLAUDE.md`).
