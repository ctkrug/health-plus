import SwiftUI

enum ChartPeriod: String, CaseIterable {
    case week = "1W"
    case month = "30D"
    case quarter = "90D"
    case year = "1Y"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

/// A single dedicated page for inspecting any health metric over time. Shows the current value, a
/// 1W/30D/90D/1Y interactive chart, and a dropdown to switch to any other metric without leaving
/// the page.
struct MetricDetailView: View {
    let metrics: [MetricSeries]
    @State private var selectedID: String
    @State private var period: ChartPeriod = .month

    init(metrics: [MetricSeries], selectedID: String) {
        self.metrics = metrics
        _selectedID = State(initialValue: selectedID)
    }

    private var metric: MetricSeries {
        metrics.first { $0.id == selectedID } ?? metrics.first
            ?? MetricSeries(id: "", title: "", unit: "", icon: "questionmark",
                            color: .accentBlue, current: nil, history: [], format: { "\($0)" })
    }

    private var displayed: [(Date, Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.days, to: Date())!
        return metric.history.filter { $0.0 >= cutoff }
    }

    private var stats: (avg: Double, min: Double, max: Double)? {
        guard !displayed.isEmpty else { return nil }
        let vals = displayed.map(\.1)
        return (vals.reduce(0, +) / Double(vals.count), vals.min()!, vals.max()!)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                metricPicker
                heroSection
                if metric.history.isEmpty {
                    if let msg = metric.noDataMessage { noDataSection(message: msg) }
                } else {
                    periodPicker
                    chartSection
                    if let s = stats { statsRow(s) }
                }
                Spacer().frame(height: 50)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Metric switcher

    private var metricPicker: some View {
        Menu {
            ForEach(metrics) { m in
                Button {
                    selectedID = m.id
                } label: {
                    Label(m.title, systemImage: m.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(metric.color)
                Text("Showing \(metric.title)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 0.5))
        }
        .padding(.top, 12)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 6) {
            Group {
                if let v = metric.current {
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text(metric.format(v))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        if !metric.unit.isEmpty {
                            Text(metric.unit)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                                .padding(.bottom, 4)
                        }
                    }
                } else {
                    Text("—")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.top, 18)

            Text("Current")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, 22)
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(ChartPeriod.allCases, id: \.self) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { period = p }
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(period == p ? metric.color : Color.clear)
                        .foregroundStyle(period == p ? .white : Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
        .padding(4)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var chartSection: some View {
        if displayed.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.textTertiary)
                Text("No data for this period")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hold and drag to scrub")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                InteractiveTrendChart(
                    points: displayed,
                    color: metric.color,
                    unit: metric.unit,
                    valueFormat: metric.format,
                    showAverage: metric.showAverage,
                    weekdayLabels: period == .week,
                    yDomainPadding: yPadding,
                    height: 220
                )
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var yPadding: Double {
        guard let s = stats, s.max > s.min else { return 1 }
        return (s.max - s.min) * 0.15
    }

    private func statsRow(_ s: (avg: Double, min: Double, max: Double)) -> some View {
        HStack(spacing: 12) {
            StatBlock(label: "Average", value: metric.format(s.avg), unit: metric.unit, color: metric.color)
            StatBlock(label: "Lowest",  value: metric.format(s.min), unit: metric.unit, color: Color.accentRed)
            StatBlock(label: "Highest", value: metric.format(s.max), unit: metric.unit, color: Color.accentGreen)
        }
        .padding(.horizontal, 20)
    }

    private func noDataSection(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 20)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat block

private struct StatBlock: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textTertiary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
    }
}

// MARK: - Reusable navigation link to the metric detail page

/// Wraps any label in a tap target that opens the unified metric detail page focused on `metricID`.
/// Use inside a NavigationStack. Build the catalog from the live services at tap time.
struct MetricNavLink<Label: View>: View {
    @Environment(AppState.self) private var appState
    let metricID: String
    @ViewBuilder var label: () -> Label

    var body: some View {
        NavigationLink {
            MetricDetailView(
                metrics: MetricCatalog.all(hk: appState.healthKitService,
                                           whoop: appState.whoopService.snapshot),
                selectedID: metricID
            )
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }
}
