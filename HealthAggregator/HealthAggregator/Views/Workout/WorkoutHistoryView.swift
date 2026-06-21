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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            store.deleteSession(session)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
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
    @State private var selectedWeek: String? = nil

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

    private var selectedValue: Double? {
        guard let selectedWeek else { return nil }
        return weeklyData.first { $0.0 == selectedWeek }?.1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Volume")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if let selectedWeek, let selectedValue {
                    Text("\(selectedWeek): \(Int(selectedValue)) lb")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentBlue)
                }
            }

            Chart(weeklyData, id: \.0) { item in
                BarMark(x: .value("Week", item.0), y: .value("lb", item.1))
                    .foregroundStyle(item.0 == selectedWeek ? Color.accentGreen.gradient : Color.accentBlue.gradient)
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
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plot = proxy.plotFrame else { return }
                                    let x = value.location.x - geo[plot].origin.x
                                    if let week: String = proxy.value(atX: x), week != selectedWeek {
                                        selectedWeek = week
                                        HapticsManager.selection()
                                    }
                                }
                        )
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
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    let session: WorkoutSession

    @State private var showDeleteAlert = false
    @State private var showSaveAsTemplate = false
    @State private var showEdit = false
    @State private var templateName = ""

    private var store: WorkoutStore { appState.workoutStore }

    private var exportText: String {
        let dateStr = session.startDate.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        let duration = "\(Int(session.duration / 60))m"
        let volume = "\(Int(session.totalVolumeKg / 0.453592).formatted()) lb"
        var lines = ["\(session.name)", "\(dateStr)  ·  \(duration)  ·  \(volume) total", ""]

        for exercise in session.exercises {
            let equipment: String
            if let eq = exercise.progressionRule?.equipment {
                equipment = " (\(eq.rawValue))"
            } else {
                let n = exercise.name.lowercased()
                if n.contains("machine") || n.contains("lat pull") || n.contains("leg press") {
                    equipment = " (Machine)"
                } else if n.contains("barbell") {
                    equipment = " (Barbell)"
                } else {
                    equipment = " (Dumbbell)"
                }
            }
            lines.append("\(exercise.name)\(equipment)")
            for set in exercise.completedSets {
                let weight = set.weightKg.map { String(format: "%.0f lb", $0 / 0.453592) } ?? "—"
                let reps = set.reps.map { "\($0)" } ?? "—"
                lines.append("  Set \(set.setNumber): \(weight) × \(reps) reps\(set.isPR ? "  🔥 PR" : "")")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: {
                        Label("Edit Workout", systemImage: "pencil")
                    }
                    Button { templateName = session.name; showSaveAsTemplate = true } label: {
                        Label("Save as Template", systemImage: "square.and.arrow.down")
                    }
                    ShareLink(item: exportText, subject: Text(session.name)) {
                        Label("Share / Export", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Workout?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                store.deleteSession(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Save as Template", isPresented: $showSaveAsTemplate) {
            TextField("Template name", text: $templateName)
            Button("Save") { saveAsTemplate() }
            Button("Cancel", role: .cancel) { templateName = "" }
        } message: {
            Text("Creates a new workout template with these exercises.")
        }
        .sheet(isPresented: $showEdit) {
            SessionEditView(session: session)
        }
    }

    private func saveAsTemplate() {
        let exercises: [TemplateExercise] = session.exercises.enumerated().map { i, ex in
            let bestSet = ex.completedSets.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) })
            return TemplateExercise(
                name: ex.name,
                orderIndex: i,
                defaultSets: max(ex.completedSets.count, 1),
                defaultReps: bestSet?.reps ?? 8,
                defaultWeightKg: bestSet?.weightKg,
                defaultWeightUnit: bestSet?.weightUnit ?? .lbs
            )
        }
        var template = WorkoutTemplate(name: templateName.isEmpty ? session.name : templateName, type: session.type)
        template.exercises = exercises
        store.saveTemplate(template)
        templateName = ""
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

// MARK: - Session Edit

struct SessionEditView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State var session: WorkoutSession

    private var store: WorkoutStore { appState.workoutStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($session.exercises) { $exercise in
                            EditExerciseCard(exercise: $exercise)
                                .padding(.horizontal, 16)
                        }
                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.updateSession(session)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.accentGreen)
                }
            }
        }
    }
}

struct EditExerciseCard: View {
    @Binding var exercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            HStack {
                Text("Set").frame(width: 36, alignment: .leading)
                Text("Weight (lb)").frame(maxWidth: .infinity)
                Text("Reps").frame(width: 60)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.textTertiary)

            ForEach($exercise.sets) { $set in
                if set.isCompleted {
                    EditSetRow(set: $set)
                }
            }
        }
        .card()
    }
}

struct EditSetRow: View {
    @Binding var set: WorkoutSet
    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack(spacing: 10) {
            Text("Set \(set.setNumber)")
                .font(.metricLabel(13))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 36, alignment: .leading)

            TextField("lb", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(8)
                .background(Color.cardBorder.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: .infinity)
                .onChange(of: weightText) { _, v in
                    if let lb = Double(v) { set.weightKg = lb * 0.453592 }
                }

            TextField("reps", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(8)
                .background(Color.cardBorder.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: 60)
                .onChange(of: repsText) { _, v in
                    if let r = Int(v) { set.reps = r }
                }
        }
        .onAppear {
            if let w = set.weightKg { weightText = String(format: "%.1f", w / 0.453592) }
            if let r = set.reps { repsText = "\(r)" }
        }
    }
}
