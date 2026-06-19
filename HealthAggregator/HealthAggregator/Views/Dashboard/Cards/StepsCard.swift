import SwiftUI

struct StepsCard: View {
    let hk: HealthKitService

    private var stepGoal: Double { hk.stepGoal }
    private var progress: Double { min(hk.steps / stepGoal, 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Steps & Calories", systemImage: "figure.walk.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(hk.steps > 0 ? Int(hk.steps).formatted() : "—")
                            .font(.metric(32))
                            .foregroundStyle(Color.accentGreen)
                        Text("steps")
                            .font(.metricLabel(13))
                            .foregroundStyle(Color.textSecondary)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.cardBorder)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentGreen)
                                .frame(width: geo.size.width * progress)
                                .animation(.spring(response: 0.6), value: progress)
                        }
                    }
                    .frame(height: 6)

                    Text("\(Int((stepGoal - hk.steps).magnitude).formatted()) to goal")
                        .font(.metricLabel(11))
                        .foregroundStyle(Color.textTertiary)
                }

                VStack(alignment: .trailing, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Int(hk.activeCalories).formatted())
                            .font(.metric(18))
                            .foregroundStyle(Color.accentRed)
                        Text("active cal")
                            .font(.metricLabel(11))
                            .foregroundStyle(Color.textSecondary)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Int(hk.restingCalories).formatted())
                            .font(.metric(18))
                            .foregroundStyle(Color.textSecondary)
                        Text("resting cal")
                            .font(.metricLabel(11))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            // 7-day sparkline
            if !hk.stepsHistory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    SparklineView(values: hk.stepsHistory, color: .accentGreen)
                    HStack {
                        Text("7-day avg: \(Int(hk.stepsHistory.reduce(0, +) / Double(hk.stepsHistory.count)).formatted())")
                            .font(.metricLabel(11))
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                    }
                }
            }
        }
        .card()
    }
}
