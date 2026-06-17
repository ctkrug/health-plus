import SwiftUI

struct ActivityRingsCard: View {
    let hk: HealthKitService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Activity", systemImage: "figure.walk.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 20) {
                // Nested rings
                ZStack {
                    RingView(progress: min(hk.activeCalories / max(hk.moveGoal, 1), 1.0),
                             color: .accentRed, lineWidth: 11, diameter: 88)
                    RingView(progress: min(hk.exerciseMinutes / max(hk.exerciseGoal, 1), 1.0),
                             color: .accentGreen, lineWidth: 11, diameter: 64)
                    RingView(progress: min(hk.standHours / max(hk.standGoal, 1), 1.0),
                             color: .accentBlue, lineWidth: 11, diameter: 40)
                }
                .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 10) {
                    ActivityRingRow(
                        color: .accentRed, label: "Move",
                        value: Int(hk.activeCalories), goal: Int(hk.moveGoal), unit: "cal"
                    )
                    ActivityRingRow(
                        color: .accentGreen, label: "Exercise",
                        value: Int(hk.exerciseMinutes), goal: Int(hk.exerciseGoal), unit: "min"
                    )
                    ActivityRingRow(
                        color: .accentBlue, label: "Stand",
                        value: Int(hk.standHours), goal: Int(hk.standGoal), unit: "hr"
                    )
                }
                Spacer()
            }
        }
        .card()
    }
}

struct ActivityRingRow: View {
    let color: Color
    let label: String
    let value: Int
    let goal: Int
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(.metricLabel(13))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.metric(15))
                    .foregroundStyle(Color.textPrimary)
                Text("/ \(goal) \(unit)")
                    .font(.metricLabel(11))
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
}
