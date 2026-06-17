import UserNotifications
import Foundation

@Observable
final class NotificationService {
    var isAuthorized = false

    func requestAuthorization() async {
        do {
            isAuthorized = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification auth error: \(error)")
        }
    }

    // MARK: - Rest Timer

    func scheduleRestTimer(seconds: Int) {
        cancelRestTimer()   // always cancel any pending before rescheduling
        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Time for your next set!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "rest_timer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelRestTimer() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest_timer"])
    }

    // MARK: - Daily Summary

    func scheduleDailySummary() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Summary"
        content.body = "Tap to see today's health snapshot."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_summary", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func updateDailySummaryContent(steps: Int, recovery: Double?, calories: Int) {
        cancelDailySummary()
        let content = UNMutableNotificationContent()
        content.title = "Daily Summary"
        var parts: [String] = ["\(steps.formatted()) steps", "\(calories.formatted()) cal"]
        if let r = recovery { parts.insert("Recovery \(Int(r))%", at: 1) }
        content.body = parts.joined(separator: " · ")
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_summary", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelDailySummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_summary"])
    }

    // MARK: - Weekly Recap

    func scheduleWeeklyRecap() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Recap"
        content.body = "See how your week went!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_recap", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Workout Reminder

    func scheduleWorkoutReminder(hour: Int, minute: Int) {
        cancelWorkoutReminder()
        let content = UNMutableNotificationContent()
        content.title = "Time to Train"
        content.body = "Your workout is waiting."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "workout_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelWorkoutReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["workout_reminder"])
    }

    // MARK: - PR celebration (local)

    func sendPRNotification(exerciseName: String, weight: Double, reps: Int) {
        let content = UNMutableNotificationContent()
        content.title = "New Personal Record!"
        content.body = "\(exerciseName): \(String(format: "%.1f", weight / 0.453592)) lb × \(reps) 🔥"
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "pr_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
