# Health+ — Setup & TestFlight Guide

## What's built
- **32 Swift files**, zero compiler errors
- **5 tabs**: Dashboard · Workout · Body · Recovery · Nutrition
- **HealthKit**: steps, calories, sleep, HRV, body comp, nutrition (reads + writes workouts)
- **WHOOP OAuth 2.0**: recovery score, strain, HRV, sleep performance
- **Renpho / MFP / Swim.com**: all read via HealthKit (setup cards guide user)
- **Workout engine**: full set-by-set logging, PR detection, confetti, rest timers, history
- **Live Activity**: workout tracker on lock screen / Dynamic Island
- **Notifications**: rest timer, daily summary, weekly recap, PR alerts
- **Dark-mode first** design system with SF Pro Display/Rounded

---

## 5 things YOU must do (total ~45 min)

### 1. Install & run setup script (5 min)
```bash
cd ~/Desktop/Claude/Personal\ Health\ APp/HealthAggregator
./setup.sh   # installs xcodegen if needed, generates HealthAggregator.xcodeproj
```
Then open **HealthAggregator.xcodeproj** in Xcode.

### 2. Set your Development Team (5 min)
In Xcode → select **HealthAggregator** target → **Signing & Capabilities** tab:
- Team: select your Apple Developer account
- Bundle ID: change `com.healthaggregator.app` to something unique (e.g. `com.charliekrug.healthplus`)
- Do the same for the **HealthAggregatorWidgets** target

### 3. Register WHOOP developer app (10 min)
1. Go to [developer.whoop.com](https://developer.whoop.com) → create an app
2. Set redirect URI to `healthaggregator://whoop/callback`
3. Copy **Client ID** and **Client Secret**
4. Open `HealthAggregator/Info.plist` → fill in:
   - `WhoopClientID` → your client ID
   - `WhoopClientSecret` → your client secret

### 4. Create app in App Store Connect (5 min)
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+**
2. Name: "Health+" (or your chosen name)
3. Bundle ID: same as what you set in Xcode
4. SKU: any unique string (e.g. `healthplus2024`)

### 5. Archive & upload for TestFlight (10 min)
In Xcode:
1. Select **Any iOS Device (arm64)** as destination
2. **Product → Archive**
3. When archive window opens → **Distribute App** → **App Store Connect** → **Upload**
4. In App Store Connect → **TestFlight** tab → add your email as internal tester

---

## Running locally (on your iPhone)
1. Connect iPhone via USB
2. Select your device in Xcode
3. `Cmd+R` to build and run
4. Trust the developer cert on your phone: Settings → General → VPN & Device Management

---

## Architecture
```
HealthAggregator/
├── App/                    # Entry point, tab view
├── Design/                 # Colors, typography, reusable components
├── Models/                 # WorkoutSession, ExerciseLibrary, WhoopModels
├── Services/
│   ├── HealthKitService    # All HK reads + workout writes
│   ├── WhoopService        # OAuth + API + 30-min background refresh
│   ├── WorkoutStore        # Core Data (programmatic model, JSON-backed)
│   ├── KeychainService     # WHOOP token storage
│   └── NotificationService # Rest timer, daily summary, reminders
├── Views/
│   ├── Dashboard/          # 7 cards: Recovery, Activity, Steps, Body, Nutrition, Sleep, Workout
│   ├── Workout/            # ActiveWorkoutView, history, complete screen, exercise picker
│   ├── Body/               # Weight/fat/lean mass charts (Renpho via HK)
│   ├── Recovery/           # WHOOP recovery + HRV trends + sleep
│   ├── Nutrition/          # Calorie ring, macros, water (MFP via HK)
│   ├── Onboarding/         # 4-screen onboarding + WHOOP connect
│   └── Settings/           # Integrations, goals, notifications
└── LiveActivity/           # WorkoutLiveActivity (lock screen + Dynamic Island)
```

## Data source setup for Renpho / MFP / Swim.com
These apps write to Apple Health natively — no API keys needed:
- **Renpho**: App → Profile → Health → toggle "Write to Apple Health"
- **MyFitnessPal**: Settings → Apps & Devices → Apple Health → enable Nutrition
- **Swim.com**: Settings → Health → enable Health sync

The app shows setup cards when data is missing to guide you through these steps.
