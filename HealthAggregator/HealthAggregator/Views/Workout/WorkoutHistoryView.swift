import SwiftUI
import Charts

struct WorkoutHistoryView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var selectedExercise: String? = nil

    var store: WorkoutStore { appState.workoutStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Volume trend chart
                        if !store.sessions.isEmpty {
                            VolumeChartCard(store: store)
                                .padding(.horizontal, 16)
                        }

                        // PR list
                        if !store.personalRecords.isEmpty {
                            PRListCard(prs: store.personalRecords)
                                .padding(.horizontal, 16)
                        }

                        // Session list grouped by week
                        let grouped = groupByWeek(store.sessions)
                        ForEach(grouped.keys.sorted(by: >), id: \.self) { weekStart in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(weekLabel(weekStart))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)
                                    .padding(.horizontal, 20)

                                ForEach(grouped[weekStart] ?? []) { session in
                                    NavigationLink {
                                        SessionDetailView(session: session)
                                    } label: {
                                        WorkoutHistoryRow(session: session)
                                            .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func groupByWeek(_ sessions: [WorkoutSession]) -> [Date: [WorkoutSession]] {
        let calendar = Calendar.current
        var dict: [Date: [WorkoutSession]] = [:]
        for session in sessions {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.startDate)!.start
            dict[weekStart, default: []].append(session)
        }
        return dict
    }

    private func weekLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInThisWeek(date) { return "This Week" }
        let end = calendar.date(byAdding: .day, value: 6, to: date)!
        return "\(date.formatted(.dateTime.month().day())) – \(end.formatted(.dateTime.month().day()))"
    }
}

extension Calendar {
    func isDateInThisWeek(_ date: Date) -> Bool {
        isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

// MARK: - Volume Chart

struct VolumeChartCard: View {
    let store: WorkoutStore

    private var weeklyData: [(String, Double)] {
        let calendar = Calendar.current
        return (0..<8).reversed().map { weekOffset in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            let vol = store.sessions
                .filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
                .reduce(0) { $0 + $1.totalVolumeKg / 0.453592 }
            let label = weekOffset == 0 ? "This" : "-\(weekOffset)w"
            return (label, vol)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Chart(weeklyData, id: \.0) { item in
                BarMark(x: .value("Week", item.0), y: .value("lb", item.1))
                    .foregroundStyle(Color.accentBlue.gradient)
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().foregroundStyle(Color.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(dash: [4])).foregroundStyle(Color.cardBorder)
                    AxisValueLabel().foregroundStyle(Color.textSecondary)
                }
            }
            .frame(height: 160)
        }
        .card()
    }
}

// MARK: - PR List

struct PRListCard: View {
    let prs: [String: PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            ForEach(prs.values.sorted { $0.exerciseName < $1.exerciseName }) { pr in
                HStack {
                    Text(pr.exerciseName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("\(String(format: "%.1f", pr.weightKg / 0.453592)) lb × \(pr.reps)")
                        .font(.metric(14))
                        .foregroundStyle(Color.accentYellow)
                    Text("e1RM \(Int(pr.estimated1RM / 0.453592))lb")
                        .font(.metricLabel(11))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .card()
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header stats
                    HStack(spacing: 0) {
                        StatPill(value: "\(Int(session.duration / 60))m", label: "Duration", color: .accentBlue)
                        Divider().frame(height: 40).overlay(Color.separatorColor)
                        StatPill(value: "\(session.completedSets)", label: "Sets", color: .accentGreen)
                        Divider().frame(height: 40).overlay(Color.separatorColor)
                        StatPill(value: "\(Int(session.totalVolumeKg / 0.453592).formatted()) lb", label: "Volume", color: .accentOrange)
                    }
                    .card(padding: 0)
                    .padding(.horizontal, 16)

                    // Exercises
                    ForEach(session.exercises) { exercise in
                        ExerciseDetailCard(exercise: exercise)
                            .padding(.horizontal, 16)
                    }
                    Spacer().frame(height: 30)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseDetailCard: View {
    let exercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            ForEach(exercise.completedSets) { set in
                HStack {
                    Text("Set \(set.setNumber)")
                        .font(.metricLabel(13))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 50, alignment: .leading)

                    if let w = set.weightKg, let r = set.reps {
                        Text("\(String(format: "%.1f", w / 0.453592)) lb × \(r)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    if set.isPR {
                        Text("PR 🔥")
                            .font(.metricLabel(12))
                            .foregroundStyle(Color.accentYellow)
                    }
                    if let e1rm = set.estimated1RM {
                        Text("e1RM \(Int(e1rm / 0.453592))lb")
                            .font(.metricLabel(11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .card()
    }
}
