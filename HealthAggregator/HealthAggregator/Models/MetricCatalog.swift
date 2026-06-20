import SwiftUI

/// One time-series metric the user can inspect on the metric detail page. Bundles the current value,
/// its dated history, and display metadata so the detail view can render — and switch between — any
/// metric from a single dropdown.
struct MetricSeries: Identifiable {
    let id: String
    let title: String
    let unit: String
    let icon: String
    let color: Color
    let current: Double?
    let history: [(Date, Double)]      // ascending by date
    let format: (Double) -> String
    var showAverage: Bool = true
    var noDataMessage: String? = nil
}

/// Builds the full list of inspectable metrics from the live services. Order here = order in the
/// detail-page dropdown. Metrics with no history (WHOOP recovery/strain) still appear so they can be
/// selected; their detail page shows the current value with a "no history" note.
enum MetricCatalog {
    static func all(hk: HealthKitService, whoop: WhoopSnapshot) -> [MetricSeries] {
        let intFmt: (Double) -> String = { Int($0.rounded()).formatted() }
        let oneDp: (Double) -> String = { String(format: "%.1f", $0) }

        var list: [MetricSeries] = []

        list.append(MetricSeries(
            id: "steps", title: "Steps", unit: "", icon: "figure.walk", color: .accentGreen,
            current: hk.steps > 0 ? hk.steps : nil,
            history: hk.stepsHistoryDated, format: intFmt))

        list.append(MetricSeries(
            id: "weight", title: "Weight", unit: "lb", icon: "scalemass.fill", color: .accentBlue,
            current: hk.weight > 0 ? hk.weight / 0.453592 : nil,
            history: hk.weightHistory.map { ($0.0, $0.1 / 0.453592) }, format: oneDp))

        list.append(MetricSeries(
            id: "bodyfat", title: "Body Fat", unit: "%", icon: "drop.fill", color: .accentOrange,
            current: hk.bodyFat > 0 ? hk.bodyFat * 100 : nil,
            history: hk.bodyFatHistory.map { ($0.0, $0.1 * 100) }, format: oneDp, showAverage: false))

        list.append(MetricSeries(
            id: "leanmass", title: "Lean Mass", unit: "lb", icon: "figure.strengthtraining.traditional",
            color: .accentGreen,
            current: hk.leanMass > 0 ? hk.leanMass / 0.453592 : nil,
            history: hk.leanMassHistory.map { ($0.0, $0.1 / 0.453592) }, format: oneDp))

        list.append(MetricSeries(
            id: "sleep", title: "Sleep", unit: "hrs", icon: "moon.zzz.fill", color: .accentBlue,
            current: hk.sleepHours > 0 ? hk.sleepHours : nil,
            history: hk.sleepHistory, format: oneDp))

        list.append(MetricSeries(
            id: "calories", title: "Calories", unit: "kcal", icon: "fork.knife", color: .accentOrange,
            current: hk.caloriesConsumed > 0 ? hk.caloriesConsumed : nil,
            history: hk.caloriesHistory, format: intFmt))

        list.append(MetricSeries(
            id: "hrv", title: "HRV", unit: "ms", icon: "waveform.path.ecg.rectangle.fill", color: .accentPurple,
            current: whoop.hrv ?? (hk.hrvMssd > 0 ? hk.hrvMssd : nil),
            history: hk.hrvHistory, format: intFmt))

        list.append(MetricSeries(
            id: "restinghr", title: "Resting HR", unit: "bpm", icon: "heart.fill", color: .accentRed,
            current: whoop.restingHR ?? (hk.restingHR > 0 ? hk.restingHR : nil),
            history: hk.restingHRHistory, format: intFmt))

        list.append(MetricSeries(
            id: "recovery", title: "Recovery", unit: "%", icon: "arrow.counterclockwise.circle.fill",
            color: .accentGreen,
            current: whoop.recoveryScore,
            history: [], format: intFmt, showAverage: false,
            noDataMessage: "WHOOP only exposes today's recovery score — historical recovery isn't available from their API."))

        list.append(MetricSeries(
            id: "strain", title: "Strain", unit: "/ 21", icon: "bolt.fill", color: .accentYellow,
            current: whoop.strain,
            history: [], format: oneDp, showAverage: false,
            noDataMessage: "WHOOP only exposes today's strain — historical strain isn't available from their API."))

        return list
    }
}
