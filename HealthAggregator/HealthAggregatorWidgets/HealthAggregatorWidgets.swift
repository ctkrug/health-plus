import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Shared types (duplicated from main target — widget has no access to app code)

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setNumber: Int
        var totalSets: Int
        var restSeconds: Int?
        var isResting: Bool
        var elapsedSeconds: Int
    }
    var workoutName: String
}

// MARK: - Live Activity Widget

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(hex: "#0A0A0F"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.workoutName, systemImage: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatElapsed(context.state.elapsedSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.exerciseName)
                                .font(.callout.bold())
                                .foregroundStyle(.white)
                            Text("Set \(context.state.setNumber) of \(context.state.totalSets)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        if context.state.isResting, let rest = context.state.restSeconds {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Rest")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                Text("\(rest)s")
                                    .font(.title3.monospacedDigit().bold())
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                if context.state.isResting, let rest = context.state.restSeconds {
                    Text("\(rest)s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.yellow)
                } else {
                    Text(formatElapsed(context.state.elapsedSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
            } minimal: {
                Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(context.state.isResting ? .yellow : .blue)
            }
        }
        .configurationDisplayName("Workout Tracker")
        .description("Track your workout on the Lock Screen and Dynamic Island.")
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Set \(context.state.setNumber) of \(context.state.totalSets)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            Spacer()
            if context.state.isResting, let rest = context.state.restSeconds {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Rest")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("\(rest)s")
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(.yellow)
                }
            } else {
                Text(formatElapsed(context.state.elapsedSeconds))
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Steps Widget

struct StepsEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let goal: Int
}

struct StepsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsEntry {
        StepsEntry(date: .now, steps: 7500, goal: 10000)
    }
    func getSnapshot(in context: Context, completion: @escaping (StepsEntry) -> Void) {
        completion(StepsEntry(date: .now, steps: 7500, goal: 10000))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsEntry>) -> Void) {
        let steps = UserDefaults(suiteName: "group.com.charliekrug.healthplus")?.integer(forKey: "widget_steps") ?? 0
        let goal = UserDefaults(suiteName: "group.com.charliekrug.healthplus")?.integer(forKey: "widget_stepGoal") ?? 10000
        let entry = StepsEntry(date: .now, steps: steps, goal: goal)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct StepsWidgetView: View {
    let entry: StepsEntry
    var progress: Double { min(Double(entry.steps) / Double(entry.goal), 1.0) }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0F")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(Color(hex: "#3B82F6"))
                        .font(.system(size: 14, weight: .semibold))
                    Text("STEPS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                        .tracking(1)
                    Spacer()
                }
                Text(entry.steps.formatted())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#1E1E2E"))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#3B82F6"))
                            .frame(width: geo.size.width * progress, height: 5)
                    }
                }
                .frame(height: 5)

                Text("Goal: \(entry.goal.formatted())")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
            .padding(14)
        }
    }
}

struct StepsWidget: Widget {
    let kind = "StepsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepsProvider()) { entry in
            StepsWidgetView(entry: entry)
                .containerBackground(Color(hex: "#0A0A0F"), for: .widget)
        }
        .configurationDisplayName("Steps")
        .description("Today's step count and goal progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Workout Summary Widget

struct WorkoutEntry: TimelineEntry {
    let date: Date
    let workoutName: String
    let duration: Int        // minutes
    let wasToday: Bool
    let streak: Int
}

struct WorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(date: .now, workoutName: "Upper Body", duration: 52, wasToday: true, streak: 5)
    }
    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        completion(WorkoutEntry(date: .now, workoutName: "Upper Body", duration: 52, wasToday: true, streak: 5))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.charliekrug.healthplus")
        let name = defaults?.string(forKey: "widget_lastWorkoutName") ?? "No workout yet"
        let duration = defaults?.integer(forKey: "widget_lastWorkoutDuration") ?? 0
        let wasToday = defaults?.bool(forKey: "widget_lastWorkoutToday") ?? false
        let streak = defaults?.integer(forKey: "widget_streak") ?? 0
        let entry = WorkoutEntry(date: .now, workoutName: name, duration: duration, wasToday: wasToday, streak: streak)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WorkoutWidgetView: View {
    let entry: WorkoutEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0F")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color(hex: "#22C55E"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(entry.wasToday ? "TODAY" : "LAST WORKOUT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                        .tracking(1)
                    Spacer()
                    if entry.streak > 0 {
                        HStack(spacing: 3) {
                            Text("🔥")
                                .font(.system(size: 11))
                            Text("\(entry.streak)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#F97316"))
                        }
                    }
                }
                Text(entry.workoutName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if entry.duration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                        Text("\(entry.duration) min")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                }

                Spacer()
                Text("Tap to open")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#3B82F6"))
            }
            .padding(14)
        }
    }
}

struct WorkoutSummaryWidget: Widget {
    let kind = "WorkoutSummaryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutProvider()) { entry in
            WorkoutWidgetView(entry: entry)
                .containerBackground(Color(hex: "#0A0A0F"), for: .widget)
        }
        .configurationDisplayName("Workout")
        .description("Your last workout and current streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct HealthAggregatorWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivityWidget()
        StepsWidget()
        WorkoutSummaryWidget()
    }
}

// MARK: - Color helper (duplicated for widget target — no access to main app)

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
