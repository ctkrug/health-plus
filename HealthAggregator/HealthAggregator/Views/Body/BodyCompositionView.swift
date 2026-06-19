import SwiftUI
import Charts

struct BodyCompositionView: View {
    @Environment(AppState.self) var appState
    @State private var selectedRange: ChartRange = .thirtyDays

    var hk: HealthKitService { appState.healthKitService }

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
                        // Top metrics
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            BodyMetricCard(label: "Weight", value: currentWeightLbs > 0 ? String(format: "%.1f", currentWeightLbs) : "—", unit: "lb", color: .accentBlue)
                            BodyMetricCard(label: "Body Fat", value: bodyFatPct > 0 ? String(format: "%.1f", bodyFatPct) : "—", unit: "%", color: .accentOrange)
                            BodyMetricCard(label: "Lean Mass", value: leanMassLbs > 0 ? String(format: "%.1f", leanMassLbs) : "—", unit: "lb", color: .accentGreen)
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
                .refreshable { await hk.refresh() }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                AppHeader<EmptyView>()
            }
            .toolbar(.hidden, for: .navigationBar)
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
