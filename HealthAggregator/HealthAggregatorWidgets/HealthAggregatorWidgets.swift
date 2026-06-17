import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Live Activity Widget

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock screen / banner
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
        .description("Track your workout progress on your lock screen.")
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

// MARK: - Widget Bundle

@main
struct HealthAggregatorWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivityWidget()
    }
}

// MARK: - Color helper (duplicated for widget target)

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
