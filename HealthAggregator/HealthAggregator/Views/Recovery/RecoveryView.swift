import SwiftUI
import Charts

struct RecoveryView: View {
    @Environment(AppState.self) var appState
    @State private var showWhoopConnect = false

    var whoop: WhoopSnapshot { appState.whoopService.snapshot }
    var hk: HealthKitService { appState.healthKitService }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if whoop.isConnected {
                            connectedContent
                        } else {
                            notConnectedContent
                        }
                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showWhoopConnect) {
                WhoopConnectView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if whoop.isConnected {
                        Button {
                            Task { await appState.whoopService.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var connectedContent: some View {
        // Big recovery score
        VStack(spacing: 20) {
            ZStack {
                let color = Color.recoveryColor(for: whoop.recoveryScore ?? 0)
                RingView(progress: (whoop.recoveryScore ?? 0) / 100, color: color, lineWidth: 16, diameter: 160)
                VStack(spacing: 4) {
                    Text(whoop.recoveryScore.map { "\(Int($0))" } ?? "—")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(color)
                    Text("RECOVERY")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .tracking(2)
                }
            }
            .padding(.top, 8)

            recoveryLabel
        }
        .padding(.horizontal, 16)

        // Personalized training guidance from recovery state (see docs/SCIENCE.md §10)
        if let guidance = InsightsEngine.recoveryGuidance(
            UserMetrics.build(hk: hk, whoop: whoop, store: appState.workoutStore)
        ) {
            RecoveryGuidanceCard(guidance: guidance)
                .padding(.horizontal, 16)
        }

        // Metrics grid
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            RecoveryMetricCard(
                icon: "waveform.path.ecg.rectangle.fill",
                label: "HRV", value: whoop.hrv.map { "\(Int($0))" } ?? "—", unit: "ms",
                color: .accentPurple
            )
            RecoveryMetricCard(
                icon: "heart.fill",
                label: "Resting HR", value: whoop.restingHR.map { "\(Int($0))" } ?? "—", unit: "bpm",
                color: .accentRed
            )
            RecoveryMetricCard(
                icon: "bolt.fill",
                label: "Strain", value: whoop.strain.map { String(format: "%.1f", $0) } ?? "—", unit: "/ 21",
                color: .accentYellow
            )
            RecoveryMetricCard(
                icon: "moon.zzz.fill",
                label: "Sleep Performance", value: whoop.sleepPerformance.map { "\(Int($0))" } ?? "—", unit: "%",
                color: .accentPurple
            )
        }
        .padding(.horizontal, 16)

        // HRV trend
        if !hk.hrvHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("HRV Trend (30 days)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    let avg = hk.hrvHistory.map(\.1).reduce(0, +) / Double(hk.hrvHistory.count)
                    Text("Avg \(Int(avg))ms")
                        .font(.metricLabel(13))
                        .foregroundStyle(Color.textSecondary)
                }

                Chart(hk.hrvHistory, id: \.0) { point in
                    LineMark(x: .value("Date", point.0), y: .value("ms", point.1))
                        .foregroundStyle(Color.accentPurple)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", point.0), y: .value("ms", point.1))
                        .foregroundStyle(Color.accentPurple.opacity(0.15).gradient)
                        .interpolationMethod(.catmullRom)
                    // Baseline
                    let avg = hk.hrvHistory.map(\.1).reduce(0, +) / Double(hk.hrvHistory.count)
                    RuleMark(y: .value("Avg", avg))
                        .lineStyle(StrokeStyle(dash: [4]))
                        .foregroundStyle(Color.textTertiary)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel().foregroundStyle(Color.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(dash: [4])).foregroundStyle(Color.cardBorder)
                        AxisValueLabel().foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(height: 150)
            }
            .card()
            .padding(.horizontal, 16)
        }

        // Sleep card in recovery context
        SleepCard(hk: hk, whoop: whoop)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    var notConnectedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.clipboard.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentBlue.opacity(0.6))
                .padding(.top, 40)

            Text("Connect WHOOP")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("Link your WHOOP device to see recovery scores, strain, HRV trends, and sleep performance.")
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                showWhoopConnect = true
            } label: {
                Text("Connect WHOOP")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 20)

            // Show HRV from HealthKit as fallback
            if !hk.hrvHistory.isEmpty {
                Text("Apple Health HRV (no WHOOP score)")
                    .font(.metricLabel(13))
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    @ViewBuilder
    var recoveryLabel: some View {
        HStack(spacing: 8) {
            if let score = whoop.recoveryScore {
                Circle()
                    .fill(Color.recoveryColor(for: score))
                    .frame(width: 10, height: 10)
                Text(recoveryStatusText(score))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            } else {
                Circle()
                    .fill(Color.textTertiary)
                    .frame(width: 10, height: 10)
                Text("Syncing recovery data…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if let updated = whoop.lastUpdated {
                Text(updated, style: .relative)
                    .font(.metricLabel(12))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 4)
    }

    private func recoveryStatusText(_ score: Double) -> String {
        switch score {
        case 67...: return "Well Recovered — Go hard today"
        case 34..<67: return "Moderate — Steady effort"
        default: return "Low Recovery — Consider rest"
        }
    }
}

struct RecoveryMetricCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            VStack(spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value).font(.metric(22)).foregroundStyle(Color.textPrimary)
                    Text(unit).font(.metricLabel(11)).foregroundStyle(Color.textSecondary)
                }
                Text(label).font(.metricLabel(12)).foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .card()
    }
}
