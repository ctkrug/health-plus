import SwiftUI

struct BodySnapshotCard: View {
    let hk: HealthKitService

    private var weightLbs: Double { hk.weight / 0.453592 }
    private var bodyFatPct: Double { hk.bodyFat * 100 }

    private var weight7DaysAgo: Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return hk.weightHistory.last(where: { $0.0 <= cutoff }).map { $0.1 / 0.453592 }
    }

    private var weightDelta: String? {
        guard let prev = weight7DaysAgo, weightLbs > 0 else { return nil }
        let delta = weightLbs - prev
        return String(format: "%+.1f lb", delta)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Body", systemImage: "figure.stand")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 0) {
                BodyMetricPill(
                    label: "Weight",
                    value: weightLbs > 0 ? String(format: "%.1f", weightLbs) : "—",
                    unit: "lb",
                    delta: weightDelta
                )
                Divider().frame(height: 40).overlay(Color.separatorColor)
                BodyMetricPill(
                    label: "Body Fat",
                    value: bodyFatPct > 0 ? String(format: "%.1f", bodyFatPct) : "—",
                    unit: "%"
                )
                Divider().frame(height: 40).overlay(Color.separatorColor)
                BodyMetricPill(
                    label: "Lean Mass",
                    value: hk.leanMass > 0 ? String(format: "%.1f", hk.leanMass / 0.453592) : "—",
                    unit: "lb"
                )
            }

            if !hk.weightHistory.isEmpty {
                SparklineView(values: hk.weightHistory.suffix(30).map { $0.1 / 0.453592 }, color: .accentBlue)
                    .frame(height: 32)
            }
        }
        .card()
    }
}

struct BodyMetricPill: View {
    let label: String
    let value: String
    let unit: String
    var delta: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.metricLabel(11))
                .foregroundStyle(Color.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.metric(20))
                    .foregroundStyle(Color.textPrimary)
                Text(unit)
                    .font(.metricLabel(11))
                    .foregroundStyle(Color.textSecondary)
            }
            if let delta {
                Text(delta)
                    .font(.metricLabel(11))
                    .foregroundStyle(delta.hasPrefix("-") ? Color.accentGreen : Color.accentRed)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
