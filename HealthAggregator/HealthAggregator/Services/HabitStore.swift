import Foundation
import SwiftUI

@Observable
final class HabitStore {
    var habits: [Habit] = []
    var logs: [HabitLog] = []
    var pendingMilestone: HabitMilestoneEvent? = nil

    var isSetupComplete: Bool {
        get { UserDefaults.standard.bool(forKey: "habitSetupComplete") }
        set { UserDefaults.standard.set(newValue, forKey: "habitSetupComplete") }
    }

    private let habitsKey        = "saved_habits"
    private let logsKey          = "saved_habit_logs"
    private let allTimeCountsKey = "habit_all_time_counts"
    private let shownMilestonesKey = "habit_shown_milestones"

    // Permanent total counts (not pruned with logs)
    private var allTimeCounts: [String: Int] = [:]
    private var shownMilestones: [String: [Int]] = [:]

    init() { load() }

    // MARK: - Completion

    func isCompleted(_ habit: Habit, slot: HabitTimeSlot, on date: Date = Date()) -> Bool {
        let key = HabitLog.dayKey(for: date)
        return logs.contains { $0.habitId == habit.id && $0.dayKey == key && $0.timeSlot == slot }
    }

    func toggle(_ habit: Habit, slot: HabitTimeSlot, on date: Date = Date()) {
        let key = HabitLog.dayKey(for: date)
        if let idx = logs.firstIndex(where: { $0.habitId == habit.id && $0.dayKey == key && $0.timeSlot == slot }) {
            logs.remove(at: idx)
            let idKey = habit.id.uuidString
            allTimeCounts[idKey] = max(0, (allTimeCounts[idKey] ?? 0) - 1)
        } else {
            logs.append(HabitLog(habitId: habit.id, dayKey: key, timeSlot: slot, completedAt: Date()))
            let idKey = habit.id.uuidString
            let newCount = (allTimeCounts[idKey] ?? 0) + 1
            allTimeCounts[idKey] = newCount
            checkMilestone(for: habit, count: newCount)
        }
        save()
        pruneOldLogs()
    }

    func totalCompletions(for habit: Habit) -> Int {
        allTimeCounts[habit.id.uuidString] ?? 0
    }

    private func checkMilestone(for habit: Habit, count: Int) {
        guard HabitMilestone.counts.contains(count) else { return }
        let idKey = habit.id.uuidString
        let shown = shownMilestones[idKey] ?? []
        guard !shown.contains(count) else { return }
        shownMilestones[idKey] = shown + [count]
        pendingMilestone = HabitMilestoneEvent(habit: habit, count: count)
        saveShownMilestones()
    }

    // MARK: - Today progress

    func todaySlots() -> [(habit: Habit, slot: HabitTimeSlot)] {
        habits.filter(\.isEnabled).flatMap { habit -> [(Habit, HabitTimeSlot)] in
            habit.timeSlot == .anytime ? [(habit, .anytime)] : [(habit, habit.timeSlot)]
        }
    }

    var todayTotal: Int { todaySlots().count }

    var todayCompleted: Int {
        todaySlots().filter { isCompleted($0.habit, slot: $0.slot) }.count
    }

    var todayFraction: Double {
        todayTotal == 0 ? 0 : Double(todayCompleted) / Double(todayTotal)
    }

    // MARK: - Streaks

    func streak(for habit: Habit, slot: HabitTimeSlot) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let todayKey = HabitLog.dayKey(for: checkDate)
        let todayDone = logs.contains { $0.habitId == habit.id && $0.dayKey == todayKey && $0.timeSlot == slot }
        if !todayDone {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        while true {
            let key = HabitLog.dayKey(for: checkDate)
            let completed = logs.contains { $0.habitId == habit.id && $0.dayKey == key && $0.timeSlot == slot }
            if completed {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else { break }
        }
        return streak
    }

    // MARK: - CRUD

    func addHabit(_ habit: Habit) {
        var h = habit
        h.orderIndex = habits.count
        habits.append(h)
        isSetupComplete = true
        save()
    }

    func updateHabit(_ habit: Habit) {
        if let idx = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[idx] = habit
            save()
        }
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        logs.removeAll { $0.habitId == habit.id }
        allTimeCounts.removeValue(forKey: habit.id.uuidString)
        shownMilestones.removeValue(forKey: habit.id.uuidString)
        save()
    }

    func reorder(_ source: IndexSet, _ dest: Int) {
        habits.move(fromOffsets: source, toOffset: dest)
        for i in habits.indices { habits[i].orderIndex = i }
        save()
    }

    // MARK: - Bulk setup from AI

    func applyAIHabits(_ incoming: [Habit]) {
        habits = incoming.enumerated().map { idx, h in var h2 = h; h2.orderIndex = idx; return h2 }
        isSetupComplete = true
        save()
    }

    /// One-time install of the four daily non-negotiables that pair with the 12-Week Build plan.
    /// Gated by a UserDefaults flag and additive (skips any habit already present by name), so it
    /// never clobbers existing habits. Triggered from `AppState`, not `init`, so the store's unit
    /// tests keep starting from an empty state.
    func installCharlieBuildHabitsIfNeeded() {
        let flag = "charlieBuildHabitsV1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        let planned: [Habit] = [
            Habit(name: "Hit 150g Protein", category: .nutrition, icon: "fork.knife",
                  colorHex: HabitCategory.nutrition.colorHex, timeSlot: .anytime,
                  notes: "Bulk fuel — about 1 g per lb of bodyweight."),
            Habit(name: "Creatine (5g)", category: .supplements, icon: "pills.fill",
                  colorHex: HabitCategory.supplements.colorHex, timeSlot: .anytime,
                  notes: "Every day — timing doesn't matter."),
            Habit(name: "Knee & Back Rehab", category: .fitness, icon: "figure.flexibility",
                  colorHex: HabitCategory.fitness.colorHex, timeSlot: .anytime,
                  notes: "McGill Big-3 + knee/hip routine, ~10 min. Pain stays ≤ 3/10."),
            Habit(name: "Log Every Set", category: .fitness, icon: "square.and.pencil",
                  colorHex: HabitCategory.fitness.colorHex, timeSlot: .anytime,
                  notes: "Progression is data, not memory."),
        ]
        for h in planned where !habits.contains(where: { $0.name == h.name }) {
            var hh = h
            hh.orderIndex = habits.count
            habits.append(hh)
        }
        if !habits.isEmpty { isSetupComplete = true }
        UserDefaults.standard.set(true, forKey: flag)
        save()
    }

    // MARK: - Grouped helpers

    func habitsForSection(_ slot: HabitTimeSlot) -> [Habit] {
        habits.filter(\.isEnabled).filter { h in
            switch slot {
            case .am:      return h.timeSlot == .am
            case .pm:      return h.timeSlot == .pm
            case .anytime: return h.timeSlot == .anytime
            }
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(habits)       { UserDefaults.standard.set(data, forKey: habitsKey) }
        if let data = try? JSONEncoder().encode(logs)         { UserDefaults.standard.set(data, forKey: logsKey) }
        if let data = try? JSONEncoder().encode(allTimeCounts){ UserDefaults.standard.set(data, forKey: allTimeCountsKey) }
        saveShownMilestones()
    }

    private func saveShownMilestones() {
        if let data = try? JSONEncoder().encode(shownMilestones) {
            UserDefaults.standard.set(data, forKey: shownMilestonesKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: habitsKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded.sorted { $0.orderIndex < $1.orderIndex }
        }
        if let data = UserDefaults.standard.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([HabitLog].self, from: data) {
            logs = decoded
        }
        if let data = UserDefaults.standard.data(forKey: allTimeCountsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            allTimeCounts = decoded
        }
        if let data = UserDefaults.standard.data(forKey: shownMilestonesKey),
           let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            shownMilestones = decoded
        }
    }

    private func pruneOldLogs() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let cutoffKey = HabitLog.dayKey(for: cutoff)
        logs = logs.filter { $0.dayKey >= cutoffKey }
    }
}
