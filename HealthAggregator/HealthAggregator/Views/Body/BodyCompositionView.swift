import SwiftUI
import Charts

struct BodyCompositionView: View {
    @Environment(AppState.self) var appState
    @State private var selectedRange: ChartRange = .thirtyDays
    @State private var showWhoopConnect = false

    var hk: HealthKitService { appState.healthKitService }
    private var whoop: WhoopSnapshot { appState.whoopService.snapshot }
    private var isWhoopConnected: Bool { appState.whoopService.isConnected }

    enum ChartRange: String, CaseIterable {
        case thirtyDays = "30D"
        case ninetyDays = "90D"
        case year = "1Y"

        var days: Int {
            switch self { case .thirtyDays: return 30; case .ninetyDays: return 90; case .year: return 365 }
        }
    }

    private var filteredWeight: [(Date, Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date())!
        return hk.weightHistory.filter { $0.0 >= cutoff }
    }

    private var filteredBodyFat: [(Date, Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date())!
        return hk.bodyFatHistory.filter { $0.0 >= cutoff }
    }

    private var currentWeightLbs: Double { hk.weight / 0.453592 }
    private var bodyFatPct: Double { hk.bodyFat * 100 }
    private var leanMassLbs: Double { hk.leanMass / 0.453592 }

    private var metrics: UserMetrics {
        UserMetrics.build(hk: hk, whoop: appState.whoopService.snapshot, store: appState.workoutStore)
    }
    private var bodyInsights: [MetricInsight] { InsightsEngine.bodyInsights(metrics) }
    private var proteinFooter: String? {
        guard let p = InsightsEngine.proteinTarget(metrics) else { return nil }
        return "Protein target: \(p.low)–\(p.high) g/day (1.6–2.2 g/kg) to build and retain muscle."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // RECOVERY (merged from the old Recovery tab) — top of the stats hub
                        recoverySection

                        bodySectionLabel("BODY COMPOSITION")

                        // Top metrics — tap any to open its dedicated trend page
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            MetricNavLink(metricID: "weight") {
                                BodyMetricCard(label: "Weight", value: currentWeightLbs > 0 ? String(format: "%.1f", currentWeightLbs) : "—", unit: "lb", color: .accentBlue)
                            }
                            MetricNavLink(metricID: "bodyfat") {
                                BodyMetricCard(label: "Body Fat", value: bodyFatPct > 0 ? String(format: "%.1f", bodyFatPct) : "—", unit: "%", color: .accentOrange)
                            }
                            MetricNavLink(metricID: "leanmass") {
                                BodyMetricCard(label: "Lean Mass", value: leanMassLbs > 0 ? String(format: "%.1f", leanMassLbs) : "—", unit: "lb", color: .accentGreen)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Secondary metrics
                        VStack(spacing: 0) {
                            MetricRow(label: "BMI", value: hk.bmi > 0 ? String(format: "%.1f", hk.bmi) : "—", unit: bmiCategory)
                            Divider().overlay(Color.separatorColor)
                            MetricRow(label: "Visceral Fat", value: hk.visceralFat > 0 ? String(format: "%.1f", hk.visceralFat) : "—", unit: "level")
                            Divider().overlay(Color.separatorColor)
                            MetricRow(label: "Skeletal Muscle", value: hk.skeletalMuscleMass > 0 ? String(format: "%.1f", hk.skeletalMuscleMass / 0.453592) : "—", unit: "lb")
                            Divider().overlay(Color.separatorColor)
                            MetricRow(label: "Body Water", value: hk.bodyWaterPercentage > 0 ? String(format: "%.1f", hk.bodyWaterPercentage) : "—", unit: "%")
                        }
                        .card()
                        .padding(.horizontal, 16)

                        // Personalized targets & insights (science-backed — see docs/SCIENCE.md)
                        if !bodyInsights.isEmpty {
                            InsightsCard(title: "Your Targets", insights: bodyInsights, footer: proteinFooter)
                                .padding(.horizontal, 16)
                        }

                        // Range picker
                        Picker("Range", selection: $selectedRange) {
                            ForEach(ChartRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        // Weight chart (interactive — drag to scrub)
                        if !filteredWeight.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Weight Trend")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)

                                InteractiveTrendChart(
                                    points: filteredWeight.map { ($0.0, $0.1 / 0.453592) },
                                    color: .accentBlue,
                                    unit: "lb",
                                    valueFormat: { String(format: "%.1f", $0) },
                                    yDomainPadding: 1.5,
                                    height: 170
                                )
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Body fat chart (interactive — drag to scrub). History values are stored as
                        // a 0–1 fraction; ×100 to display whole percents (matches the headline metric).
                        if !filteredBodyFat.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Body Fat %")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)

                                InteractiveTrendChart(
                                    points: filteredBodyFat.map { ($0.0, $0.1 * 100) },
                                    color: .accentOrange,
                                    unit: "%",
                                    valueFormat: { String(format: "%.1f", $0) },
                                    showAverage: false,
                                    yDomainPadding: 2,
                                    height: 150
                                )
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Renpho setup banner
                        if hk.weight == 0 {
                            SetupBanner(
                                icon: "scalemass.fill",
                                message: "Enable Renpho → Health sync to see body composition data",
                                color: .accentBlue
                            )
                            .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await hk.refresh()
                    if isWhoopConnected { await appState.whoopService.refresh() }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                AppHeader<EmptyView>()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWhoopConnect) { WhoopConnectView() }
            .task { if isWhoopConnected { await appState.whoopService.refresh() } }
        }
    }

    // MARK: - Recovery section (merged from the old Recovery tab)

    @ViewBuilder
    private var recoverySection: some View {
        if isWhoopConnected {
            VStack(spacing: 16) {
                ZStack {
                    let score = whoop.recoveryScore ?? 0
                    let color = Color.recoveryColor(for: score)
                    RingView(progress: score / 100, color: color, lineWidth: 14, diameter: 132)
                    VStack(spacing: 2) {
                        if let s = whoop.recoveryScore {
                            Text("\(Int(s))")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .foregroundStyle(color)
                        } else {
                            Text("—")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Text("RECOVERY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                            .tracking(2)
                    }
                }
                .padding(.top, 4)

                if let score = whoop.recoveryScore {
                    HStack(spacing: 8) {
                        Circle().fill(Color.recoveryColor(for: score)).frame(width: 9, height: 9)
                        Text(recoveryStatusText(score))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)

            if let guidance = InsightsEngine.recoveryGuidance(metrics) {
                RecoveryGuidanceCard(guidance: guidance)
                    .padding(.horizontal, 16)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricNavLink(metricID: "hrv") {
                    MetricTile(icon: "waveform.path.ecg.rectangle.fill", label: "HRV",
                               value: whoop.hrv.map { "\(Int($0))" } ?? (hk.hrvMssd > 0 ? "\(Int(hk.hrvMssd))" : "—"),
                               unit: "ms", color: .accentPurple, sparkData: hk.hrvHistory.map(\.1))
                }
                MetricNavLink(metricID: "restinghr") {
                    MetricTile(icon: "heart.fill", label: "Resting HR",
                               value: whoop.restingHR.map { "\(Int($0))" } ?? (hk.restingHR > 0 ? "\(Int(hk.restingHR))" : "—"),
                               unit: "bpm", color: .accentRed, sparkData: hk.restingHRHistory.map(\.1))
                }
                MetricNavLink(metricID: "sleep") {
                    MetricTile(icon: "moon.zzz.fill", label: "Sleep",
                               value: hk.sleepHours > 0 ? String(format: "%.1f", hk.sleepHours) : "—",
                               unit: "hrs", color: .accentBlue, sparkData: hk.sleepHistory.map(\.1))
                }
                MetricNavLink(metricID: "strain") {
                    MetricTile(icon: "bolt.fill", label: "Strain",
                               value: whoop.strain.map { String(format: "%.1f", $0) } ?? "—",
                               unit: "/ 21", color: .accentYellow, sparkData: [])
                }
            }
            .padding(.horizontal, 16)
        } else {
            // Compact WHOOP connect prompt (full ring lives here once connected)
            Button { showWhoopConnect = true } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: "#1A1A2E"))
                        .frame(width: 40, height: 40)
                        .overlay(Text("W").font(.system(size: 20, weight: .black)).foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect WHOOP")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Recovery, strain, HRV & sleep")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(14)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    private func bodySectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textTertiary)
                .tracking(1.5)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func recoveryStatusText(_ score: Double) -> String {
        switch score {
        case 67...: return "Well Recovered — Go hard today"
        case 34..<67: return "Moderate — Steady effort"
        default: return "Low Recovery — Consider rest"
        }
    }

    private var bmiCategory: String {
        switch hk.bmi {
        case 0: return ""
        case ..<18.5: return "Underweight"
        case ..<25: return "Normal"
        case ..<30: return "Overweight"
        default: return "Obese"
        }
    }
}

// MARK: - Metric Tile (recovery key-metric tiles; moved from the old Recovery tab)

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

struct BodyMetricCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.metricLabel(12))
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(.metric(24))
                .foregroundStyle(color)
            Text(unit)
                .font(.metricLabel(11))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
    }
}
