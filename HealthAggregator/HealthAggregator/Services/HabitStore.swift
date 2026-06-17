import Foundation
import SwiftUI

@Observable
final class HabitStore {
    var habits: [Habit] = []
    var logs: [HabitLog] = []
    var isSetupComplete: Bool {
        get { UserDefaults.standard.bool(forKey: "habitSetupComplete") }
        set { UserDefaults.standard.set(newValue, forKey: "habitSetupComplete") }
    }

    private let habitsKey = "saved_habits"
    private let logsKey = "saved_habit_logs"

    init() {
        load()
    }

    // MARK: - Completion

    func isCompleted(_ habit: Habit, slot: HabitTimeSlot, on date: Date = Date()) -> Bool {
        let key = HabitLog.dayKey(for: date)
        return logs.contains { $0.habitId == habit.id && $0.dayKey == key && $0.timeSlot == slot }
    }

    func toggle(_ habit: Habit, slot: HabitTimeSlot, on date: Date = Date()) {
        let key = HabitLog.dayKey(for: date)
        if let idx = logs.firstIndex(where: { $0.habitId == habit.id && $0.dayKey == key && $0.timeSlot == slot }) {
            logs.remove(at: idx)
        } else {
            logs.append(HabitLog(habitId: habit.id, dayKey: key, timeSlot: slot, completedAt: Date()))
        }
        save()
        pruneOldLogs()
    }

    // MARK: - Today progress

    func todaySlots() -> [(habit: Habit, slot: HabitTimeSlot)] {
        habits.filter(\.isEnabled).flatMap { habit -> [(Habit, HabitTimeSlot)] in
            if habit.timeSlot == .anytime {
                return [(habit, .anytime)]
            } else {
                return [(habit, habit.timeSlot)]
            }
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

        while true {
            let key = HabitLog.dayKey(for: checkDate)
            let completed = logs.contains { $0.habitId == habit.id && $0.dayKey == key && $0.timeSlot == slot }
            if completed {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - CRUD

    func addHabit(_ habit: Habit) {
        var h = habit
        h.orderIndex = habits.count
        habits.append(h)
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
        save()
    }

    func reorder(_ source: IndexSet, _ dest: Int) {
        habits.move(fromOffsets: source, toOffset: dest)
        for i in habits.indices { habits[i].orderIndex = i }
        save()
    }

    // MARK: - Bulk setup from AI

    func applyAIHabits(_ incoming: [Habit]) {
        habits = incoming.enumerated().map { idx, h in
            var h2 = h; h2.orderIndex = idx; return h2
        }
        isSetupComplete = true
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
        if let data = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(data, forKey: habitsKey)
        }
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: logsKey)
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
    }

    private func pruneOldLogs() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let cutoffKey = HabitLog.dayKey(for: cutoff)
        logs = logs.filter { $0.dayKey >= cutoffKey }
    }
}
