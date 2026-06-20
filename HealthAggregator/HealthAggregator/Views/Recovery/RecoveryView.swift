import SwiftUI
import Charts

struct RecoveryView: View {
    @Environment(AppState.self) var appState
    @State private var showWhoopConnect = false

    // Use service.isConnected (set on token exchange) not snapshot.isConnected (set on first data fetch)
    var isConnected: Bool { appState.whoopService.isConnected }
    var whoop: WhoopSnapshot { appState.whoopService.snapshot }
    var hk: HealthKitService { appState.healthKitService }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if isConnected {
                            connectedContent
                        } else {
                            notConnectedContent
                        }
                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    if isConnected { await appState.whoopService.refresh() }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                AppHeader()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWhoopConnect) {
                WhoopConnectView()
            }
            .task {
                // Pull fresh data when the tab appears if connected but data is missing/stale.
                if isConnected { await appState.whoopService.refresh() }
            }
        }
    }

    // MARK: - Connected

    @ViewBuilder
    var connectedContent: some View {
        // Big recovery ring
        VStack(spacing: 16) {
            ZStack {
                let score = whoop.recoveryScore ?? 0
                let color = Color.recoveryColor(for: score)
                RingView(progress: score / 100, color: color, lineWidth: 16, diameter: 160)
                VStack(spacing: 4) {
                    if let s = whoop.recoveryScore {
                        Text("\(Int(s))")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                    } else {
                        Text("—")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textTertiary)
                    }
                    Text("RECOVERY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .tracking(2)
                }
            }
            .padding(.top, 8)

            recoveryLabel
        }
        .padding(.horizontal, 16)

        // Personalized training guidance
        if let guidance = InsightsEngine.recoveryGuidance(
            UserMetrics.build(hk: hk, whoop: whoop, store: appState.workoutStore)
        ) {
            RecoveryGuidanceCard(guidance: guidance)
                .padding(.horizontal, 16)
        }

        // Section title
        HStack {
            Text("KEY METRICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textTertiary)
                .tracking(1.5)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)

        // 2×2 tappable metric tiles → unified metric detail page
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricNavLink(metricID: "hrv") {
                MetricTile(
                    icon: "waveform.path.ecg.rectangle.fill",
                    label: "HRV",
                    value: whoop.hrv.map { "\(Int($0))" } ?? (hk.hrvMssd > 0 ? "\(Int(hk.hrvMssd))" : "—"),
                    unit: "ms",
                    color: .accentPurple,
                    sparkData: hk.hrvHistory.map(\.1)
                )
            }

            MetricNavLink(metricID: "restinghr") {
                MetricTile(
                    icon: "heart.fill",
                    label: "Resting HR",
                    value: whoop.restingHR.map { "\(Int($0))" } ?? (hk.restingHR > 0 ? "\(Int(hk.restingHR))" : "—"),
                    unit: "bpm",
                    color: .accentRed,
                    sparkData: hk.restingHRHistory.map(\.1)
                )
            }

            MetricNavLink(metricID: "sleep") {
                MetricTile(
                    icon: "moon.zzz.fill",
                    label: "Sleep",
                    value: hk.sleepHours > 0 ? String(format: "%.1f", hk.sleepHours) : "—",
                    unit: "hrs",
                    color: .accentBlue,
                    sparkData: hk.sleepHistory.map(\.1)
                )
            }

            MetricNavLink(metricID: "strain") {
                MetricTile(
                    icon: "bolt.fill",
                    label: "Strain",
                    value: whoop.strain.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "/ 21",
                    color: .accentYellow,
                    sparkData: []
                )
            }
        }
        .padding(.horizontal, 16)

        // Sleep performance from WHOOP (if available, separate from Apple Health sleep)
        if let perf = whoop.sleepPerformance {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentPurple)
                Text("WHOOP sleep score: **\(Int(perf))%**")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    // MARK: - Not connected

    @ViewBuilder
    var notConnectedContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#1A1A2E"))
                    .frame(width: 80, height: 80)
                Text("W")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.top, 40)

            Text("Connect WHOOP")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("Link your WHOOP device to unlock recovery scores, strain, HRV, and sleep performance.")
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

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

            // Show Apple Health HRV as fallback when available
            if !hk.hrvHistory.isEmpty {
                VStack(spacing: 8) {
                    Text("Apple Health HRV (no WHOOP score)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                    MetricNavLink(metricID: "hrv") {
                        MetricTile(
                            icon: "waveform.path.ecg.rectangle.fill",
                            label: "HRV",
                            value: hk.hrvMssd > 0 ? "\(Int(hk.hrvMssd))" : "—",
                            unit: "ms",
                            color: .accentPurple,
                            sparkData: hk.hrvHistory.map(\.1)
                        )
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Recovery label

    @ViewBuilder
    var recoveryLabel: some View {
        HStack(spacing: 8) {
            if let score = whoop.recoveryScore {
                Circle()
                    .fill(Color.recoveryColor(for: score))
                    .frame(width: 9, height: 9)
                Text(recoveryStatusText(score))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            } else {
                Circle().fill(Color.textTertiary).frame(width: 9, height: 9)
                Text("Syncing recovery data…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if let updated = whoop.lastUpdated {
                Text(updated, style: .relative)
                    .font(.system(size: 12, weight: .medium))
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

// MARK: - Metric Tile

struct MetricTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color
    let sparkData: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                if sparkData.count >= 3 {
                    SparklineView(values: sparkData.suffix(14).map { $0 }, color: color, height: 26)
                        .frame(width: 52)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
        .contentShape(Rectangle())
    }
}
