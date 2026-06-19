import SwiftUI
import Charts

enum ChartPeriod: String, CaseIterable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

struct MetricDetailView: View {
    let title: String
    let unit: String
    let icon: String
    let color: Color
    let history: [(Date, Double)]
    let currentValue: Double?
    let formatValue: (Double) -> String
    let noDataMessage: String?

    @State private var period: ChartPeriod = .month

    init(title: String, unit: String, icon: String, color: Color,
         history: [(Date, Double)], currentValue: Double?,
         formatValue: @escaping (Double) -> String,
         noDataMessage: String? = nil) {
        self.title = title
        self.unit = unit
        self.icon = icon
        self.color = color
        self.history = history
        self.currentValue = currentValue
        self.formatValue = formatValue
        self.noDataMessage = noDataMessage
    }

    var displayed: [(Date, Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.days, to: Date())!
        return history.filter { $0.0 >= cutoff }
    }

    var chartStats: (avg: Double, min: Double, max: Double)? {
        guard !displayed.isEmpty else { return nil }
        let vals = displayed.map(\.1)
        return (vals.reduce(0, +) / Double(vals.count), vals.min()!, vals.max()!)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    if let msg = noDataMessage, history.isEmpty {
                        noDataSection(message: msg)
                    } else {
                        periodPicker
                        chartSection
                        if let s = chartStats { statsRow(s) }
                    }
                    Spacer().frame(height: 50)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(color)
                .padding(.top, 20)

            Group {
                if let v = currentValue {
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text(formatValue(v))
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        Text(unit)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.bottom, 4)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Text("Current")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, 24)
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
                        .background(period == p ? color : Color.clear)
                        .foregroundStyle(period == p ? .white : Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
        .padding(4)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
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
            VStack(alignment: .leading, spacing: 0) {
                Chart(displayed, id: \.0) { pt in
                    LineMark(x: .value("Date", pt.0), y: .value(unit, pt.1))
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", pt.0), y: .value(unit, pt.1))
                        .foregroundStyle(
                            LinearGradient(colors: [color.opacity(0.25), color.opacity(0.0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                    if let s = chartStats {
                        RuleMark(y: .value("Avg", s.avg))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(Color.textTertiary)
                            .annotation(position: .trailing) {
                                Text("avg")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.textTertiary)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: period == .week ? 7 : 5)) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.cardBorder)
                        AxisValueLabel {
                            if let d = val.as(Date.self) {
                                Text(period == .week
                                     ? d.formatted(.dateTime.weekday(.abbreviated))
                                     : d.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.cardBorder)
                        AxisValueLabel()
                            .foregroundStyle(Color.textSecondary)
                            .font(.system(size: 11))
                    }
                }
                .frame(height: 220)
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func statsRow(_ s: (avg: Double, min: Double, max: Double)) -> some View {
        HStack(spacing: 12) {
            StatBlock(label: "Average", value: formatValue(s.avg), unit: unit, color: color)
            StatBlock(label: "Lowest",  value: formatValue(s.min), unit: unit, color: Color.accentRed)
            StatBlock(label: "Highest", value: formatValue(s.max), unit: unit, color: Color.accentGreen)
        }
        .padding(.horizontal, 20)
    }

    private func noDataSection(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 38))
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 30)
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
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
    }
}
