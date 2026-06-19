import SwiftUI
import Charts

/// A reusable time-series line/area chart with a **draggable scrubber**: touch or drag anywhere on
/// the plot and a vertical line snaps to the nearest data point, showing its date + value in a
/// floating "lollipop" label. Lift your finger and the marker stays so the value is readable.
///
/// Used by every trend chart in the app (metric drill-downs, body composition) so the scrubbing
/// interaction is identical everywhere.
struct InteractiveTrendChart: View {
    let points: [(date: Date, value: Double)]
    var color: Color = .accentBlue
    var unit: String = ""
    var valueFormat: (Double) -> String = { String(format: "%.0f", $0) }
    var showAverage: Bool = true
    var weekdayLabels: Bool = false        // true → "Mon/Tue", false → "Jun 3"
    var yDomainPadding: Double = 0          // pad the y-scale by this much above/below the data
    var height: CGFloat = 220

    @State private var selectedDate: Date? = nil

    init(points: [(Date, Double)],
         color: Color = .accentBlue,
         unit: String = "",
         valueFormat: @escaping (Double) -> String = { String(format: "%.0f", $0) },
         showAverage: Bool = true,
         weekdayLabels: Bool = false,
         yDomainPadding: Double = 0,
         height: CGFloat = 220) {
        self.points = points.map { (date: $0.0, value: $0.1) }
        self.color = color
        self.unit = unit
        self.valueFormat = valueFormat
        self.showAverage = showAverage
        self.weekdayLabels = weekdayLabels
        self.yDomainPadding = yDomainPadding
        self.height = height
    }

    private var average: Double? {
        guard !points.isEmpty else { return nil }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    private var selectedPoint: (date: Date, value: Double)? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Chart {
            ForEach(points, id: \.date) { pt in
                LineMark(x: .value("Date", pt.date), y: .value(unit, pt.value))
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", pt.date), y: .value(unit, pt.value))
                    .foregroundStyle(
                        LinearGradient(colors: [color.opacity(0.22), color.opacity(0.0)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
            }

            if showAverage, let average {
                RuleMark(y: .value("Avg", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(Color.textTertiary)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("avg").font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                    }
            }

            // Scrubber: vertical line + point + value lollipop at the selected sample.
            if let sel = selectedPoint {
                RuleMark(x: .value("Selected", sel.date))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .foregroundStyle(color.opacity(0.6))
                    .annotation(position: .top, spacing: 6,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        lollipop(for: sel)
                    }

                PointMark(x: .value("Selected", sel.date), y: .value(unit, sel.value))
                    .foregroundStyle(color)
                    .symbolSize(140)
                PointMark(x: .value("Selected", sel.date), y: .value(unit, sel.value))
                    .foregroundStyle(Color.appBackground)
                    .symbolSize(50)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: weekdayLabels ? 7 : 5)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.cardBorder)
                AxisValueLabel {
                    if let d = val.as(Date.self) {
                        Text(weekdayLabels
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
                AxisValueLabel().foregroundStyle(Color.textSecondary).font(.system(size: 11))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in updateSelection(at: value.location, proxy: proxy, geo: geo) }
                    )
                    // A discrete tap also selects (covers a quick tap with zero drag movement).
                    .onTapGesture { location in updateSelection(at: location, proxy: proxy, geo: geo) }
            }
        }
        .frame(height: height)
    }

    // MARK: - Lollipop label

    @ViewBuilder
    private func lollipop(for sel: (date: Date, value: Double)) -> some View {
        VStack(spacing: 2) {
            Text(sel.date.formatted(.dateTime.month(.abbreviated).day().year(.twoDigits)))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(valueFormat(sel.value))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(color.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
    }

    // MARK: - Y domain

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        if lo == hi { return (lo - 1)...(hi + 1) }
        return (lo - yDomainPadding)...(hi + yDomainPadding)
    }

    // MARK: - Gesture → nearest sample

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard !points.isEmpty, let plotAnchor = proxy.plotFrame else { return }
        let xInPlot = location.x - geo[plotAnchor].origin.x
        guard let touchedDate: Date = proxy.value(atX: xInPlot) else { return }
        let nearest = points.min {
            abs($0.date.timeIntervalSince(touchedDate)) < abs($1.date.timeIntervalSince(touchedDate))
        }
        guard let nearest else { return }
        if nearest.date != selectedDate {
            selectedDate = nearest.date
            HapticsManager.selection()   // light tick only when we land on a new data point
        }
    }
}
