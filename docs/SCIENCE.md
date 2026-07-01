# Metrics & Algorithms — Science Reference (internal, not user-facing)

This document records the science, thresholds, and reasoning behind every personalized target
and recommendation in the app. It exists so we can audit, tune, or correct the logic later.

**Where the code lives:** `Services/InsightsEngine.swift` (pure functions) + `Models/HealthInsights.swift`
(types). Each function header references the section number below. When you change a number in code,
update the matching section here.

All thresholds are population reference points, not medical advice. The app frames them as guidance.

---

## 1. Body Fat % — classification & targets

Source of categories: **American Council on Exercise (ACE)** body-fat norms, consistent with
ACSM classifications.

| Category    | Men      | Women    |
|-------------|----------|----------|
| Essential   | 2–5%     | 10–13%   |
| Athletic    | 6–13%    | 14–20%   |
| Fitness     | 14–17%   | 21–24%   |
| Average     | 18–24%   | 25–31%   |
| Obese       | 25%+     | 32%+     |

- **"Healthy lean" target band** used by the app: Men **10–17%**, Women **18–25%** (spans athletic→fitness;
  visible abs roughly <12% men / <20% women, communicated softly).
- **Age adjustment:** acceptable body fat rises with age. We add ~+1% per decade over 40 to the upper
  bound of the healthy band (Jackson & Pollock generalized equations age term; AACVPR norms).
- **Below essential is flagged as a risk** (hormonal/health), not praised.

Refs:
- Jackson AS, Pollock ML. *Generalized equations for predicting body density of men.* Br J Nutr. 1978.
- ACE Body Fat Percentage Norms (Bryant & Green, ACE Personal Trainer Manual).

---

## 2. Muscle mass — Fat-Free Mass Index (FFMI)

We assess muscularity with **normalized FFMI** rather than raw lean mass (height-independent).

```
FFM (kg)        = leanBodyMass (from HealthKit) , or weight × (1 − bodyFatFraction) if lean mass absent
FFMI            = FFM / height_m²
normalized FFMI = FFMI + 6.1 × (1.8 − height_m)     // adjusts to a 1.8 m reference height
```

Interpretation (normalized, men; women run ~3 points lower):

| normFFMI | Meaning (men)                |
|----------|------------------------------|
| < 18     | Below average muscle         |
| 18–20    | Average                      |
| 20–22    | Fit / above average          |
| 22–25    | Very muscular                |
| ~25      | Approx. natural ceiling      |
| > 25     | Rarely reached drug-free     |

- Kouri et al. (1995): 42 drug-free athletes all had normFFMI ≤ 25 (mean **21.8 ± 1.8**); steroid users 25–35.
- This is a population guideline; genetic outliers exceed 25 naturally. We never assert PED use — we cap the
  "progress toward natural potential" bar at 25 and label >23 as "elite."

Refs:
- Kouri EM, Pope HG, Katz DL, Oliva P. *Fat-free mass index in users and nonusers of anabolic-androgenic steroids.* Clin J Sport Med. 1995;5(4):223-228.
- Nuckols G. *What everyone gets wrong about FFMI and the "natty limit."* (caveat discussion)

---

## 3. Realistic muscle-gain rate (Aragon / Helms / McDonald model)

Monthly muscle gain as a fraction of bodyweight, by training experience:

| Experience          | Rate / month (of bodyweight) |
|---------------------|------------------------------|
| Beginner (<12 mo)   | 1.0–1.5%                     |
| Intermediate (1–3 y)| 0.5–1.0%                     |
| Advanced (>3 y)     | 0.25–0.5%                    |

- We infer experience from **months since the user's first logged workout** (fallback: beginner).
- Used to set realistic expectations ("at your level, ~X–Y lb/month is realistic") and to avoid
  overpromising. Assumes ≥2×/week per muscle, adequate protein, 7–9 h sleep.

Refs:
- Aragon AA, Schoenfeld BJ. *Nutrient timing revisited.* J Int Soc Sports Nutr. 2013 (model popularized by Aragon).
- Helms ER et al. *Evidence-based recommendations for natural bodybuilding contest prep.* J Int Soc Sports Nutr. 2014.
- McDonald L. *What's My Genetic Muscular Potential?* bodyrecomposition.com.

---

## 4. Strength progression (already implemented in ProgressionEngine)

Double-progression / linear logic lives in `ProgressionEngine.swift`. Rate-of-gain context:

- **Novice:** can add load nearly every session (linear progression).
- **Intermediate:** progress on a weekly timescale (e.g., double progression within a rep range).
- **Advanced:** monthly/block timescale.

Smallest sensible load jumps (in `Equipment.defaultProgressionKg`): barbell/dumbbell/cable 2.27 kg (≈2.5 lb),
machine 4.54 kg (≈10 lb). e1RM uses the **Epley formula** `1RM = w × (1 + reps/30)`.

Refs:
- Rippetoe M, Baker A. *Practical Programming for Strength Training* (novice→intermediate→advanced framework).
- Helms ER et al. *The Muscle & Strength Pyramid: Training.* 2019.
- Epley B. *Poundage Chart.* Boyd Epley Workout. 1985 (1RM estimate).

---

## 5. Cardiorespiratory fitness — VO₂max

Reference: **FRIEND registry** (Fitness Registry and the Importance of Exercise National Database),
which superseded older ACSM cutoffs for the modern US population.

50th-percentile VO₂max (mL/kg/min) by age & sex (FRIEND, treadmill):

| Age   | Men 50th | Women 50th |
|-------|----------|------------|
| 20–29 | 48       | 38         |
| 30–39 | 43       | 34         |
| 40–49 | 39       | 31         |
| 50–59 | 35       | 28         |
| 60–69 | 30       | 24         |
| 70–79 | 24       | 18         |

Rating uses the ratio `vo2 / ref50` for the user's bracket (documented approximation, not exact percentile):

| ratio       | rating         |
|-------------|----------------|
| < 0.85      | Below average  |
| 0.85–1.00   | Average        |
| 1.00–1.15   | Good           |
| 1.15–1.30   | Excellent      |
| > 1.30      | Superior       |

Decline is ~10%/decade untrained; training can offset much of it. VO₂max is one of the strongest
predictors of all-cause mortality.

Refs:
- Kaminsky LA et al. *Reference standards for cardiorespiratory fitness… FRIEND registry.* Mayo Clin Proc. 2015;90(11):1515-1523.
- Ross R et al. *Importance of assessing cardiorespiratory fitness in clinical practice.* Circulation. 2016 (AHA statement).

---

## 6. Cardio volume (weekly activity)

- **150 min/week moderate** OR **75 min/week vigorous** aerobic activity, plus **≥2 days/week** resistance training.
- We estimate weekly aerobic minutes from HealthKit `appleExerciseTime` (rolling) and compare to 150.

Refs:
- *Physical Activity Guidelines for Americans, 2nd ed.* (US HHS, 2018).
- WHO *Guidelines on physical activity and sedentary behaviour.* 2020.
- ACSM *Guidelines for Exercise Testing and Prescription, 11th ed.*

---

## 7. Daily steps

- Mortality benefit rises steeply then plateaus: **~6,000–8,000 steps/day for adults ≥60**, **~8,000–10,000 for <60**.
- Default goal 10,000 (configurable). We treat ≥8,000 as "in the protective range" for under-60s, ≥7,000 for 60+.

Refs:
- Paluch AE et al. *Daily steps and all-cause mortality: a meta-analysis of 15 international cohorts.* Lancet Public Health. 2022;7(3):e219-e228.

---

## 8. Protein target

- **1.6–2.2 g per kg bodyweight per day.** 1.6 is the meta-analytic breakpoint for maximizing
  resistance-training gains; 2.2 is the defensible upper bound (and useful during fat loss for satiety/muscle retention).
- App shows a range = `round(1.6×kg) … round(2.2×kg)`. For high body fat we note that lean-mass-based
  targets may be more appropriate.

Refs:
- Morton RW et al. *A systematic review, meta-analysis… protein supplementation on resistance training-induced gains.* Br J Sports Med. 2018;52(6):376-384.
- Jäger R et al. *ISSN position stand: protein and exercise.* J Int Soc Sports Nutr. 2017.

---

## 9. Sleep

- **7–9 hours/night** for adults (18–64); 7–8 for 65+.
- We flag <7 h as under-target and show the deficit.

Refs:
- Hirshkowitz M et al. *National Sleep Foundation's sleep time duration recommendations.* Sleep Health. 2015;1(1):40-43.

---

## 10. WHOOP recovery, HRV, resting HR

- **Recovery bands (WHOOP):** Green **≥67%** (primed), Yellow **34–66%** (moderate), Red **<34%** (strained).
- **Training guidance** keyed to the band:
  - Green → good day for high strain / heavy or high-volume training.
  - Yellow → maintenance / moderate; auto-regulate.
  - Red → prioritize recovery; light aerobic or rest.
- **HRV** is individual — interpret relative to the user's **30-day rolling baseline** (we have `hrvHistory`).
  Today notably below baseline (we use <85% of baseline) suggests accumulated fatigue/illness/poor sleep.
- **Resting HR** trending **above** baseline (>+5 bpm) is an additional fatigue/illness flag.

Refs:
- WHOOP. *Understanding Recovery, HRV, and Strain* (WHOOP Locker / methodology docs).
- Plews DJ et al. *Training adaptation and HRV in elite endurance athletes.* Eur J Appl Physiol. 2013 (baseline-relative HRV).
- Stanley J, Peake JM, Buchheit M. *Cardiac parasympathetic reactivation following exercise.* Sports Med. 2013.

---

## 10. Supersets — Pairing Logic & Science

**Code:** `Services/SupersetEngine.swift`

### What the research says

A **superset** is two (or more) exercises performed back-to-back with minimal rest between them.
Three distinct types exist; the app recommends only types 1 and 3 because they preserve or enhance
performance on the second exercise:

| Type | Definition | Performance effect on 2nd set |
|------|-----------|-------------------------------|
| **Antagonist** | Opposing muscle groups (bench → row) | **+5–15% more reps** vs straight sets (Robbins 2009, Paz 2017) |
| **Agonist (compound sets)** | Same muscle twice (incline → flat bench) | −10–20% reps; not recommended for strength |
| **Non-competing** | Unrelated muscles (bench → leg curl) | Neutral; saves time but no PAP benefit |

The mechanism for the antagonist boost is twofold:
1. **Reciprocal inhibition:** the nervous system relaxes the antagonist when the agonist contracts —
   doing a set of rows first makes the chest "turn off" more efficiently on the next bench set.
2. **Post-activation potentiation (PAP):** light activation of the antagonist potentiates agonist
   force output in the immediately following set.

Paz et al. (2017) found antagonist paired sets produced **equivalent or greater total volume** in
the same or less training time compared to straight sets with equal rest. Time savings in their
protocol: ~30% workout duration reduction.

### Recommended pairings (used by SupersetEngine)

The app scores pairs by movement-pattern antagonism. Score 3 = direct antagonist (maximum benefit),
score 1 = non-competing (time-efficient only):

| Pattern A | Pattern B | Score | Classic example |
|-----------|-----------|-------|-----------------|
| Horizontal Push | Horizontal Pull | 3 | Bench Press ↔ Dumbbell Row |
| Vertical Push | Vertical Pull | 3 | OHP ↔ Lat Pulldown |
| Elbow Flexion (biceps) | Elbow Extension (triceps) | 3 | Curl ↔ Tricep Extension |
| Knee Dominant (quads) | Hip Dominant (hamstrings/glutes) | 3 | Squat ↔ RDL / Leg Ext ↔ Leg Curl |
| Anterior Shoulder | Posterior Shoulder | 2 | Lateral Raise ↔ Rear Delt Fly |
| Upper Body (any) | Lower Body (any) | 1 | Bench ↔ Leg Curl (non-competing) |

Pairs with score < 1 (same muscle group or same movement pattern) are never recommended.

### Rest intervals with supersets

Within a superset: **0–15 s** transition between exercises A and B (just switch stations).
After completing both: **60–90 s** rest before the next round. Net rest per muscle is the time to
complete the partner's set — typically 30–45 s per exercise — which is adequate for hypertrophy
loads (8–15 reps) but not for maximal strength (1–5RM). For heavy strength work, full 2–3 min rest
between rounds is recommended.

The app does not currently limit supersets by load; users working at low rep ranges should increase
the between-round rest manually.

### Classification heuristics

`SupersetEngine.classify(_ exercise: TemplateExercise)` identifies movement pattern via:
1. Lookup of `muscleGroups` from `ExerciseLibrary.find(name)` (most reliable)
2. Keyword match on exercise name (fallback for user-created exercises)

Priority order when muscle groups overlap (e.g., a row also works biceps): the **primary mover**
determines the pattern. "Lats / Mid Back" → Horizontal Pull even if "Biceps" also appears.

Refs:
- Robbins DW, Young WB, Behm DG. *The effect of an upper-body agonist-antagonist resistance training
  protocol on volume load and efficiency.* J Strength Cond Res. 2010;24(10):2632–40.
- Paz GA, Robbins DW, de Oliveira CG, et al. *Volume load and neuromuscular fatigue during an acute
  bout of agonist-antagonist paired sets vs. traditional sets.* J Strength Cond Res. 2017;31(8):2087–93.
- Weakley JJ, Till K, Read DB, et al. *The effects of superset configuration on kinetic, kinematic,
  and RPE measures during a compound resistance training protocol.* J Strength Cond Res. 2020;34(1):65–72.
- Farinatti PTV, Alves BC. *Influence of rest interval lengths on blood pressure, heart rate, and
  perceived exertion following a strength training session in older women.* J Strength Cond Res. 2013.
- Maia MF et al. *Effects of different rest intervals between antagonist paired sets on repetition
  performance and muscle activation.* J Strength Cond Res. 2015;29(10):2816–24.

---

## 11. Muscle balance & symmetry

Implemented in `Services/MuscleBalanceEngine.swift`. Taxonomy is `MuscleMap.Muscle` (third-party
package, not an app-defined enum — see `Models/MuscleTaxonomy.swift`).

**⚠️ Rigor note:** unlike every other section of this document, the specific numbers below are
**field-consensus estimates** (Renaissance Periodization's published volume-landmark framework,
cross-checked against Schoenfeld's dose-response meta-analyses) rather than numbers pulled directly
from a single peer-reviewed source with a stated CI. They're good enough to gate a UI status
("under/optimal/over"), but a citation-verification pass against the primary literature (not just
widely-circulated secondary summaries) should happen before this section is held to the same bar as
§1–10. Flagged in docs/SPEC-lift-charts-and-muscle-map.md §2.5 as follow-up work.

### Fractional set-volume counting

An exercise trains multiple muscles unevenly. `MuscleBalanceEngine.weeklyVolume` gives the primary
mover full credit per completed set and every secondary/synergist mover half credit — the standard
approach in RP-style volume tracking and mirrored by consumer volume trackers (Hevy, Strong).
Example: Bench Press (primary chest, secondary triceps + front delts) → 1 set = 1.0 toward chest,
0.5 toward triceps, 0.5 toward front delts.

### Weekly volume landmarks (MEV / MRV, working sets/week, natural lifter)

| Muscle | MEV | MRV |
|---|---|---|
| Chest | 8 | 20 |
| Back (lats + mid-back, `Muscle.upperBack`) | 10 | 25 |
| Lower Back | 2 | 10 |
| Traps | 4 | 16 |
| Shoulders (all delt heads combined) | 6 | 22 |
| Rotator Cuff | 2 | 10 |
| Biceps | 6 | 20 |
| Triceps | 6 | 18 |
| Quads | 8 | 20 |
| Hamstrings | 6 | 16 |
| Glutes | 4 | 16 |
| Inner Thighs (adductors) | 2 | 10 |
| Calves | 8 | 20 |
| Abs | 0* | 20 |
| Obliques | 0* | 16 |

\* trained substantially as a synergist in compound lifts and carries; no MEV is required to make progress.

MEV (Minimum Effective Volume) / MRV (Maximum Recoverable Volume) framework: Israetel M, Hoffmann J,
et al. *Renaissance Periodization — Scientific Principles of Hypertrophy Training* (RP methodology,
widely cited but not itself a single peer-reviewed paper — treat as expert-consensus, not primary
literature). Cross-checked against: Schoenfeld BJ, Ogborn D, Krieger JW. *Dose-response relationship
between weekly resistance training volume and increases in muscle mass: A systematic review and
meta-analysis.* J Sports Sci. 2017;35(11):1073–82.

### Antagonist / agonist ratio checks

Independent of absolute volume — classic strength-and-conditioning / injury-prevention ratios, using
weekly set-volume as a training-emphasis proxy (not a true force-output ratio):

- **Hamstrings : Quads**, target **0.6–0.8**. Quad-dominant training is a documented knee-strain
  risk factor; low hamstring:quad ratios are used in ACL-injury-risk screening. Refs: Coombs R,
  Garbutt G. *Developments in the use of the hamstring/quadriceps ratio for the assessment of muscle
  balance.* J Sports Sci Med. 2002;1(3):56–62.
- **Pull : Push**, target **1.0–1.5**. Chronic push-dominant training is linked to rounded-shoulder
  posture and shoulder-impingement risk. Ref: Kluemper M, Uhl T, Hazelrigg H. *Effect of stretching
  and strengthening shoulder muscles on forward shoulder posture in competitive swimmers.* J Sport
  Rehabil. 2006;15(1):58–70 (posture/muscle-balance mechanism).
- **Posterior Chain (lower back + glutes + hamstrings) : Anterior Core (abs + obliques)**, target
  **0.8–1.5**. Balanced core training is associated with lower low-back-pain risk. Ref: McGill SM.
  *Low back disorders: evidence-based prevention and rehabilitation.* 2nd ed. Human Kinetics; 2007
  (core-balance / spine-stability framework).

These two checks (H:Q, posterior:anterior core) are flagged as **rehab-relevant** in the engine
(`MuscleBalanceEngine.rehabRelevant`) given the app's current 12-Week Build program targets knee and
back rehab specifically — recommendations weight these muscles ahead of purely aesthetic imbalances.

### Minimum sample gate

No muscle (or the composite score) is scored below **14 days** of total training history — a fresh
account or a muscle nobody's trained yet should show "not enough data," not a misleading red flag.

---

## Maintenance notes
- All numbers are centralized in `InsightsEngine.swift`. No thresholds should be hardcoded in views.
- Profile inputs (sex, age, height, VO₂max) come from HealthKit characteristic/quantity types in
  `HealthKitService`. If unavailable, the engine degrades gracefully (sex-neutral / hides that insight).
- Keep this file and the code in lockstep; cite a source for any new threshold.
- Muscle-balance volume/ratio numbers (§11) are field-consensus estimates, not single-source citations
  — see the rigor note at the top of that section before treating them as settled.
