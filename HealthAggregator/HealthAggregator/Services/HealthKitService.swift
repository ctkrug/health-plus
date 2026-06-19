import HealthKit
import SwiftUI
import WidgetKit

@Observable
final class HealthKitService {
    private let store = HKHealthStore()

    // Cached values
    var steps: Double = 0
    var stepGoal: Double = 10000
    var activeCalories: Double = 0
    var restingCalories: Double = 0
    var exerciseMinutes: Double = 0
    var standHours: Double = 0
    var moveGoal: Double = 500
    var exerciseGoal: Double = 30
    var standGoal: Double = 12
    var heartRate: Double = 0
    var hrvMssd: Double = 0
    var restingHR: Double = 0
    var weight: Double = 0          // kg
    var bodyFat: Double = 0         // fraction 0–1
    var leanMass: Double = 0        // kg
    var bmi: Double = 0
    var visceralFat: Double = 0
    var skeletalMuscleMass: Double = 0
    var bodyWaterPercentage: Double = 0
    var caloriesConsumed: Double = 0
    var calorieGoal: Double = 2500
    var proteinGrams: Double = 0
    var carbGrams: Double = 0
    var fatGrams: Double = 0
    var fiberGrams: Double = 0
    var waterMl: Double = 0
    var sleepHours: Double = 0
    var remHours: Double = 0
    var deepHours: Double = 0
    var lightHours: Double = 0
    var awakeHours: Double = 0

    // Profile / fitness (for the personalized insights engine — see docs/SCIENCE.md)
    var biologicalSex: HKBiologicalSex = .notSet
    var age: Int = 0
    var heightMeters: Double = 0
    var vo2Max: Double = 0                  // mL/kg/min
    var weeklyExerciseMinutes: Double = 0   // last 7 days, Apple exercise time

    var stepsHistory: [Double] = []     // last 7 days
    var weightHistory: [(Date, Double)] = []
    var bodyFatHistory: [(Date, Double)] = []
    var hrvHistory: [(Date, Double)] = []

    var isAuthorized = false
    var isLoading = false

    private let readTypes: Set<HKObjectType> = {
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .basalEnergyBurned,
            .appleExerciseTime, .appleStandTime,
            .heartRate, .heartRateVariabilitySDNN, .restingHeartRate,
            .bodyMass, .bodyFatPercentage, .leanBodyMass, .bodyMassIndex,
            .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates,
            .dietaryFatTotal, .dietaryFiber, .dietaryWater,
            .vo2Max, .oxygenSaturation, .height,
        ]
        var types: Set<HKObjectType> = Set(quantityTypes.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        types.insert(HKObjectType.activitySummaryType())
        types.insert(HKObjectType.workoutType())
        if let sex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) { types.insert(sex) }
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) { types.insert(dob) }
        return types
    }()

    private let writeTypes: Set<HKSampleType> = {
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned, .dietaryWater, .distanceSwimming,
        ]
        var types: Set<HKSampleType> = Set(quantityTypes.compactMap { HKSampleType.quantityType(forIdentifier: $0) })
        types.insert(HKObjectType.workoutType())
        return types
    }()

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            await MainActor.run { isAuthorized = true }
            await refresh()
        } catch {
            print("HealthKit auth error: \(error)")
        }
    }

    func refresh() async {
        // Mutate observable state on the main actor (avoids background-thread @Observable races)
        await MainActor.run {
            isLoading = true
            loadGoalsFromSettings()
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchSteps() }
            group.addTask { await self.fetchActivityRings() }
            group.addTask { await self.fetchRestingCalories() }
            group.addTask { await self.fetchHeartMetrics() }
            group.addTask { await self.fetchBodyComposition() }
            group.addTask { await self.fetchNutrition() }
            group.addTask { await self.fetchSleep() }
            group.addTask { await self.fetchStepsHistory() }
            group.addTask { await self.fetchWeightHistory() }
            group.addTask { await self.fetchBodyFatHistory() }
            group.addTask { await self.fetchHRVHistory() }
            group.addTask { await self.fetchProfile() }
            group.addTask { await self.fetchVO2Max() }
            group.addTask { await self.fetchWeeklyExerciseMinutes() }
        }
        await MainActor.run {
            isLoading = false
            writeWidgetData()
        }
    }

    // MARK: - Profile & fitness fetches (see docs/SCIENCE.md §2, §5, §6)

    private func fetchProfile() async {
        // Biological sex + age are read-only "characteristics" (synchronous, may throw if not shared)
        var sex: HKBiologicalSex = .notSet
        var computedAge = 0
        if let s = try? store.biologicalSex() { sex = s.biologicalSex }
        if let dob = try? store.dateOfBirthComponents(),
           let year = Calendar.current.date(from: dob) {
            computedAge = Calendar.current.dateComponents([.year], from: year, to: Date()).year ?? 0
        }
        let height = await fetchQuantityMostRecent(
            .height, unit: .meter(),
            start: Calendar.current.date(byAdding: .year, value: -10, to: Date())!, end: Date()
        )
        let finalSex = sex, finalAge = computedAge   // immutable copies for the closure
        await MainActor.run {
            biologicalSex = finalSex
            if finalAge > 0 { age = finalAge }
            if height > 0 { heightMeters = height }
        }
    }

    private func fetchVO2Max() async {
        // "ml/kg/min" (two slashes) correctly parses as mL·kg⁻¹·min⁻¹.
        // The old string "ml/kg*min" parsed left-to-right as mL·min/kg (wrong), causing an
        // uncatchable Obj-C exception in doubleValue(for:). fetchQuantityMostRecent also guards
        // with is(compatibleWith:) as a belt-and-suspenders check.
        let vo2Unit = HKUnit(from: "ml/kg/min")
        let value = await fetchQuantityMostRecent(
            .vo2Max, unit: vo2Unit,
            start: Calendar.current.date(byAdding: .month, value: -6, to: Date())!, end: Date()
        )
        await MainActor.run { vo2Max = value }
    }

    private func fetchWeeklyExerciseMinutes() async {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let value = await fetchQuantitySum(.appleExerciseTime, unit: .minute(), start: start, end: Date())
        await MainActor.run { weeklyExerciseMinutes = value }
    }

    private func loadGoalsFromSettings() {
        let defaults = UserDefaults.standard
        let storedCal = defaults.double(forKey: "calorieGoal")
        if storedCal > 0 { calorieGoal = storedCal }
        let storedSteps = defaults.double(forKey: "stepGoal")
        if storedSteps > 0 { stepGoal = storedSteps }
    }

    private func fetchRestingCalories() async {
        let value = await fetchQuantitySum(
            .basalEnergyBurned, unit: .kilocalorie(),
            start: Calendar.current.startOfDay(for: Date()), end: Date()
        )
        await MainActor.run { restingCalories = value }
    }

    func performBackgroundSync() async {
        await refresh()
    }

    // MARK: - Fetch implementations

    private func fetchSteps() async {
        let value = await fetchQuantitySum(
            .stepCount, unit: .count(),
            start: Calendar.current.startOfDay(for: Date()), end: Date()
        )
        await MainActor.run { steps = value }
    }

    private func fetchActivityRings() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day, .month, .year], from: today)
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: components, end: components)

        return await withCheckedContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { [weak self] _, summaries, _ in
                guard let self, let summary = summaries?.first else {
                    continuation.resume()
                    return
                }
                Task { @MainActor in
                    self.activeCalories = self.safeDouble(summary.activeEnergyBurned, unit: .kilocalorie())
                    self.exerciseMinutes = self.safeDouble(summary.appleExerciseTime, unit: .minute())
                    self.standHours = self.safeDouble(summary.appleStandHours, unit: .count())
                    self.moveGoal = self.safeDouble(summary.activeEnergyBurnedGoal, unit: .kilocalorie())
                    self.exerciseGoal = self.safeDouble(summary.appleExerciseTimeGoal, unit: .minute())
                    self.standGoal = self.safeDouble(summary.appleStandHoursGoal, unit: .count())
                    continuation.resume()
                }
            }
            store.execute(query)
        }
    }

    private func fetchHeartMetrics() async {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        async let hr = fetchQuantityMostRecent(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: weekAgo, end: now)
        async let rhr = fetchQuantityMostRecent(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: weekAgo, end: now)
        async let hrv = fetchQuantityMostRecent(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: weekAgo, end: now)

        let (heartRateVal, rhrVal, hrvVal) = await (hr, rhr, hrv)
        await MainActor.run {
            heartRate = heartRateVal
            restingHR = rhrVal
            hrvMssd = hrvVal
        }
    }

    private func fetchBodyComposition() async {
        let now = Date()
        let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!

        async let w = fetchQuantityMostRecent(.bodyMass, unit: .gramUnit(with: .kilo), start: yearAgo, end: now)
        async let bf = fetchQuantityMostRecent(.bodyFatPercentage, unit: .percent(), start: yearAgo, end: now)
        async let lm = fetchQuantityMostRecent(.leanBodyMass, unit: .gramUnit(with: .kilo), start: yearAgo, end: now)
        async let bmiVal = fetchQuantityMostRecent(.bodyMassIndex, unit: .count(), start: yearAgo, end: now)

        let (wVal, bfVal, lmVal, bmiValue) = await (w, bf, lm, bmiVal)
        await MainActor.run {
            weight = wVal
            bodyFat = bfVal   // .percent() returns a fraction 0–1, no division needed
            leanMass = lmVal
            bmi = bmiValue
        }
    }

    private func fetchNutrition() async {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()

        async let cal = fetchQuantitySum(.dietaryEnergyConsumed, unit: .kilocalorie(), start: start, end: end)
        async let prot = fetchQuantitySum(.dietaryProtein, unit: .gram(), start: start, end: end)
        async let carbs = fetchQuantitySum(.dietaryCarbohydrates, unit: .gram(), start: start, end: end)
        async let fat = fetchQuantitySum(.dietaryFatTotal, unit: .gram(), start: start, end: end)
        async let fiber = fetchQuantitySum(.dietaryFiber, unit: .gram(), start: start, end: end)
        async let water = fetchQuantitySum(.dietaryWater, unit: .literUnit(with: .milli), start: start, end: end)

        let (c, p, cr, f, fi, w) = await (cal, prot, carbs, fat, fiber, water)
        await MainActor.run {
            caloriesConsumed = c
            proteinGrams = p
            carbGrams = cr
            fatGrams = f
            fiberGrams = fi
            waterMl = w
        }
    }

    private func fetchSleep() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                guard let self else { continuation.resume(); return }
                let sleepSamples = samples as? [HKCategorySample] ?? []
                var asleep = 0.0, rem = 0.0, deep = 0.0, light = 0.0, awake = 0.0

                for sample in sleepSamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                    case .asleepREM: rem += duration
                    case .asleepDeep: deep += duration
                    case .asleepCore: light += duration
                    case .awake: awake += duration
                    default: break
                    }
                    if sample.value != HKCategoryValueSleepAnalysis.awake.rawValue
                        && sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue {
                        asleep += duration
                    }
                }

                Task { @MainActor in
                    self.sleepHours = asleep
                    self.remHours = rem
                    self.deepHours = deep
                    self.lightHours = light
                    self.awakeHours = awake
                    continuation.resume()
                }
            }
            store.execute(query)
        }
    }

    private func fetchStepsHistory() async {
        let now = Date()
        let calendar = Calendar.current
        var dailySteps: [Double] = []
        for day in (0..<7).reversed() {
            let start = calendar.date(byAdding: .day, value: -day, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let v = await fetchQuantitySum(.stepCount, unit: .count(), start: start, end: end)
            dailySteps.append(v)
        }
        await MainActor.run { stepsHistory = dailySteps }
    }

    private func fetchWeightHistory() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let self else { continuation.resume(); return }
                let unit = HKUnit.gramUnit(with: .kilo)
                let data = (samples as? [HKQuantitySample] ?? []).compactMap { s -> (Date, Double)? in
                    guard s.quantity.is(compatibleWith: unit) else { return nil }
                    return (s.startDate, s.quantity.doubleValue(for: unit))
                }
                Task { @MainActor in self.weightHistory = data; continuation.resume() }
            }
            store.execute(query)
        }
    }

    private func fetchBodyFatHistory() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let self else { continuation.resume(); return }
                let unit = HKUnit.percent()
                let data = (samples as? [HKQuantitySample] ?? []).compactMap { s -> (Date, Double)? in
                    guard s.quantity.is(compatibleWith: unit) else { return nil }
                    return (s.startDate, s.quantity.doubleValue(for: unit))
                }
                Task { @MainActor in self.bodyFatHistory = data; continuation.resume() }
            }
            store.execute(query)
        }
    }

    private func fetchHRVHistory() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let self else { continuation.resume(); return }
                let unit = HKUnit.secondUnit(with: .milli)
                let data = (samples as? [HKQuantitySample] ?? []).compactMap { s -> (Date, Double)? in
                    guard s.quantity.is(compatibleWith: unit) else { return nil }
                    return (s.startDate, s.quantity.doubleValue(for: unit))
                }
                Task { @MainActor in self.hrvHistory = data; continuation.resume() }
            }
            store.execute(query)
        }
    }

    // MARK: - Write workout to HealthKit

    func writeWorkout(_ session: WorkoutSession) async throws {
        let activityType: HKWorkoutActivityType = session.type.isSwim ? .swimming : .traditionalStrengthTraining
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        if session.type.isSwim { config.swimmingLocationType = session.type == .poolSwim ? .pool : .openWater }

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: session.startDate)

        // Add energy burned sample
        if let endDate = session.endDate {
            let energySample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: estimateCalories(session)),
                start: session.startDate, end: endDate
            )
            try await builder.addSamples([energySample])

            // Swim laps
            if session.type.isSwim {
                var lapSamples: [HKSample] = []
                for exercise in session.exercises {
                    for set in exercise.sets where set.isCompleted {
                        if let dist = set.distanceMeters {
                            let lapSample = HKQuantitySample(
                                type: HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!,
                                quantity: HKQuantity(unit: .meter(), doubleValue: dist),
                                start: session.startDate, end: endDate
                            )
                            lapSamples.append(lapSample)
                        }
                    }
                }
                if !lapSamples.isEmpty { try await builder.addSamples(lapSamples) }
            }

            try await builder.endCollection(at: endDate)
            try await builder.finishWorkout()
        }
    }

    private func estimateCalories(_ session: WorkoutSession) -> Double {
        // Rough estimate: 5 cal/min for strength, 8 cal/min for swim
        let minutes = session.duration / 60
        return minutes * (session.type.isSwim ? 8 : 5)
    }

    // MARK: - Widget data

    private func writeWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.ctkrug.healthplus")
        defaults?.set(Int(steps), forKey: "widget_steps")
        defaults?.set(Int(stepGoal), forKey: "widget_stepGoal")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Helpers

    /// Guards against unit-incompatibility ObjC exceptions that Swift try/catch cannot intercept.
    private func safeDouble(_ quantity: HKQuantity, unit: HKUnit) -> Double {
        quantity.is(compatibleWith: unit) ? quantity.doubleValue(for: unit) : 0
    }

    private func fetchQuantitySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [self] _, stats, _ in
                guard let sum = stats?.sumQuantity() else { continuation.resume(returning: 0); return }
                continuation.resume(returning: self.safeDouble(sum, unit: unit))
            }
            store.execute(query)
        }
    }

    private func fetchQuantityMostRecent(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { [self] _, samples, _ in
                guard let q = (samples as? [HKQuantitySample])?.first?.quantity else {
                    continuation.resume(returning: 0); return
                }
                continuation.resume(returning: self.safeDouble(q, unit: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Water quick-add
    func addWater(ml: Double) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml),
            start: Date(), end: Date()
        )
        try await store.save(sample)
        waterMl += ml
    }
}
