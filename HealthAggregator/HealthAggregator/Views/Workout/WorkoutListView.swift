import SwiftUI

struct WorkoutListView: View {
    @Environment(AppState.self) var appState
    @State private var showActiveWorkout = false
    @State private var showHistory = false
    @State private var showCustomBuilder = false
    @State private var showPrograms = false
    @State private var selectedTemplate: WorkoutTemplate? = nil
    @State private var programSession: WorkoutSession? = nil

    var store: WorkoutStore { appState.workoutStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Active workout banner
                        if store.isInWorkout {
                            ActiveWorkoutBanner()
                                .padding(.horizontal, 16)
                        }

                        // Stats strip
                        WorkoutStatsStrip(store: store)
                            .padding(.horizontal, 16)

                        // Active program card
                        if let prog = store.activeProgram {
                            VStack(alignment: .leading, spacing: 0) {
                                SectionHeader(title: "YOUR PROGRAM", action: "All Programs") {
                                    showPrograms = true
                                }
                                .padding(.bottom, 12)

                                ActiveProgramCard(program: prog) {
                                    if let session = store.startProgramWorkout() {
                                        programSession = session
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Quick start templates
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Quick Start", action: "Custom") {
                                showCustomBuilder = true
                            }
                            .padding(.bottom, 12)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(store.templates) { template in
                                    TemplateCard(template: template) {
                                        selectedTemplate = template
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Recent workouts
                        if !store.sessions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Recent", action: "See All") {
                                    showHistory = true
                                }
                                ForEach(store.sessions.prefix(3)) { session in
                                    WorkoutHistoryRow(session: session)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Workout")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showActiveWorkout) {
                ActiveWorkoutView(session: store.currentSession ?? WorkoutSession(name: "", type: .custom, startDate: Date()))
            }
            .sheet(isPresented: $showHistory) {
                WorkoutHistoryView()
            }
            .sheet(isPresented: $showCustomBuilder) {
                CustomWorkoutBuilderView()
            }
            .sheet(isPresented: $showPrograms) {
                ProgramView()
            }
            .sheet(item: $selectedTemplate) { template in
                ActiveWorkoutView(session: store.startWorkout(from: template))
            }
            .sheet(item: $programSession) { session in
                ActiveWorkoutView(session: session)
            }
        }
    }
}

// MARK: - Active banner

struct ActiveWorkoutBanner: View {
    @Environment(AppState.self) var appState
    @State private var showActiveWorkout = false

    var body: some View {
        Button {
            showActiveWorkout = true
        } label: {
            HStack {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(Color.accentRed)
                    .symbolEffect(.pulse)
                Text("Workout in Progress")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(14)
            .background(Color.accentRed.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentRed.opacity(0.3), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showActiveWorkout) {
            if let session = appState.workoutStore.currentSession {
                ActiveWorkoutView(session: session)
            }
        }
    }
}

// MARK: - Stats strip

struct WorkoutStatsStrip: View {
    let store: WorkoutStore

    private var thisWeek: [WorkoutSession] { store.sessionsThisWeek() }
    private var streak: WorkoutStreak { store.streak }

    var body: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(thisWeek.count)", label: "This Week", color: .accentBlue)
            Divider().frame(height: 36).overlay(Color.separatorColor)
            StatPill(value: "\(streak.currentDays)", label: "Day Streak", color: .accentYellow)
            Divider().frame(height: 36).overlay(Color.separatorColor)
            StatPill(value: "\(store.sessions.count)", label: "All Time", color: .accentGreen)
        }
        .card(padding: 0)
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.metric(22)).foregroundStyle(color)
            Text(label).font(.metricLabel(11)).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Template card

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: template.type.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentBlue)
                    Spacer()
                    if let last = template.lastUsed {
                        Text(last.formatted(.relative(presentation: .named)))
                            .font(.metricLabel(10))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                Text(template.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(template.exercises.count) exercises")
                    .font(.metricLabel(12))
                    .foregroundStyle(Color.textSecondary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History row

struct WorkoutHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 8) {
                    Text(session.startDate, style: .date)
                    Text("·")
                    Text("\(Int(session.duration / 60))m")
                    if session.totalVolumeKg > 0 {
                        Text("·")
                        Text("\(Int(session.totalVolumeKg / 0.453592).formatted()) lb vol")
                    }
                }
                .font(.metricLabel(12))
                .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: session.type.icon)
                .foregroundStyle(Color.accentBlue)
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Custom builder stub

struct CustomWorkoutBuilderView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var selectedType: WorkoutType = .custom
    @State private var exercises: [TemplateExercise] = []
    @State private var showExercisePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section("Name") {
                        TextField("Workout name", text: $name)
                            .listRowBackground(Color.cardBackground)
                    }
                    Section("Type") {
                        Picker("Type", selection: $selectedType) {
                            ForEach(WorkoutType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                    Section("Exercises") {
                        ForEach(exercises) { ex in
                            Text(ex.name)
                                .foregroundStyle(Color.textPrimary)
                                .listRowBackground(Color.cardBackground)
                        }
                        .onDelete { exercises.remove(atOffsets: $0) }
                        .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
                        Button("Add Exercise") { showExercisePicker = true }
                            .foregroundStyle(Color.accentBlue)
                            .listRowBackground(Color.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Custom Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(name.isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { ex in
                    exercises.append(TemplateExercise(name: ex.name, orderIndex: exercises.count))
                }
            }
        }
    }

    private func saveAndDismiss() {
        var template = WorkoutTemplate(name: name, type: selectedType)
        template.exercises = exercises
        appState.workoutStore.saveTemplate(template)
        dismiss()
    }
}
