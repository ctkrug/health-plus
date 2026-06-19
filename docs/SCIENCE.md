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

## Maintenance notes
- All numbers are centralized in `InsightsEngine.swift`. No thresholds should be hardcoded in views.
- Profile inputs (sex, age, height, VO₂max) come from HealthKit characteristic/quantity types in
  `HealthKitService`. If unavailable, the engine degrades gracefully (sex-neutral / hides that insight).
- Keep this file and the code in lockstep; cite a source for any new threshold.
