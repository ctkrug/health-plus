import SwiftUI
import Charts

struct SleepCard: View {
    let hk: HealthKitService
    let whoop: WhoopSnapshot

    private var sleepHours: Double { hk.sleepHours }
    private var sleepPerformance: Double? { whoop.sleepPerformance }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Sleep", systemImage: "moon.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            HStack(alignment: .center, spacing: 20) {
                // Sleep duration big number
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(sleepHours > 0 ? "\(Int(sleepHours))h \(Int((sleepHours.truncatingRemainder(dividingBy: 1)) * 60))m" : "—")
                            .font(.metric(28))
                            .foregroundStyle(Color.accentPurple)
                    }
                    Text("total sleep")
                        .font(.metricLabel(12))
                        .foregroundStyle(Color.textSecondary)

                    if let perf = sleepPerformance {
                        HStack(spacing: 4) {
                            Image(systemName: "w.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentBlue)
                            Text("\(Int(perf))% performance")
                                .font(.metricLabel(12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Sleep stage breakdown bars
                if sleepHours > 0 {
                    VStack(alignment: .trailing, spacing: 6) {
                        SleepStageRow(label: "REM", hours: hk.remHours, color: .accentPurple, total: sleepHours)
                        SleepStageRow(label: "Deep", hours: hk.deepHours, color: .accentBlue, total: sleepHours)
                        SleepStageRow(label: "Light", hours: hk.lightHours, color: Color(hex: "#6E6EAA"), total: sleepHours)
                        SleepStageRow(label: "Awake", hours: hk.awakeHours, color: Color.textTertiary, total: sleepHours)
                    }
                }
            }

            // Sleep quality bar
            if sleepHours > 0 {
                SleepBar(rem: hk.remHours, deep: hk.deepHours, light: hk.lightHours, awake: hk.awakeHours)
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .card()
    }
}

struct SleepStageRow: View {
    let label: String
    let hours: Double
    let color: Color
    let total: Double

    private var text: String {
        guard hours > 0 else { return "—" }
        let h = Int(hours)
        let m = Int((hours.truncatingRemainder(dividingBy: 1)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.metricLabel(11))
                .foregroundStyle(Color.textSecondary)
            Text(text)
                .font(.metric(12))
                .foregroundStyle(Color.textPrimary)
        }
    }
}

struct SleepBar: View {
    let rem: Double
    let deep: Double
    let light: Double
    let awake: Double

    private var total: Double { rem + deep + light + awake }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                if total > 0 {
                    Rectangle().fill(Color.accentBlue).frame(width: geo.size.width * (deep / total))
                    Rectangle().fill(Color(hex: "#6E6EAA")).frame(width: geo.size.width * (light / total))
                    Rectangle().fill(Color.accentPurple).frame(width: geo.size.width * (rem / total))
                    Rectangle().fill(Color.textTertiary).frame(width: max(0, geo.size.width * (awake / total)))
                }
            }
        }
    }
}
