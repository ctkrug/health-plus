import SwiftUI

struct WorkoutListView: View {
    @Environment(AppState.self) var appState
    @State private var showHistory = false
    @State private var showCustomBuilder = false
    @State private var showPrograms = false
    @State private var preview: WorkoutPreviewItem? = nil

    var store: WorkoutStore { appState.workoutStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // In-progress workout (resume)
                        if store.isInWorkout {
                            ActiveWorkoutBanner()
                                .padding(.horizontal, 16)
                        }

                        // TODAY — the one thing you most likely want
                        if let session = store.previewProgramSession(), let prog = store.activeProgram {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("TODAY")
                                TodayWorkoutHeroCard(
                                    title: prog.nextWorkout?.name ?? "Workout",
                                    label: prog.nextWorkout?.label ?? "",
                                    programName: prog.name,
                                    exerciseCount: session.exercises.count
                                ) {
                                    preview = WorkoutPreviewItem(
                                        title: prog.nextWorkout?.name ?? "Workout",
                                        subtitle: prog.name,
                                        session: session
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // YOUR WORKOUTS — quick-pick defaults (ABC, swim, etc.)
                        if !store.templates.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionLabel("YOUR WORKOUTS")
                                VStack(spacing: 10) {
                                    ForEach(store.templates) { template in
                                        WorkoutOptionRow(
                                            name: template.name,
                                            icon: template.type.icon,
                                            detail: "\(template.exercises.count) exercises"
                                        ) {
                                            preview = WorkoutPreviewItem(
                                                title: template.name,
                                                subtitle: template.type.rawValue,
                                                session: store.previewSession(for: template)
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // SECONDARY — everything else is one tap away, but out of the way
                        HStack(spacing: 10) {
                            SecondaryActionButton(title: "History", icon: "clock.arrow.circlepath") { showHistory = true }
                            SecondaryActionButton(title: "Programs", icon: "square.stack.3d.up.fill") { showPrograms = true }
                            SecondaryActionButton(title: "New", icon: "plus") { showCustomBuilder = true }
                        }
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 8)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                AppHeader()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showHistory) { WorkoutHistoryView() }
            .sheet(isPresented: $showCustomBuilder) { CustomWorkoutBuilderView() }
            .sheet(isPresented: $showPrograms) { ProgramView() }
            .sheet(item: $preview) { item in WorkoutPreviewView(item: item) }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.textTertiary)
            .tracking(1.2)
    }
}

// MARK: - Today hero card

struct TodayWorkoutHeroCard: View {
    let title: String
    let label: String
    let programName: String
    let exerciseCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(label.isEmpty ? "Next Up" : "Workout \(label)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentBlue)
                        Text(title)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(programName)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.accentBlue.opacity(0.45))
                }

                HStack {
                    Label("\(exerciseCount) exercises", systemImage: "list.bullet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("View & Start")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Color.accentBlue)
                        .clipShape(Capsule())
                }
            }
            .padding(18)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout option row

struct WorkoutOptionRow: View {
    let name: String
    let icon: String
    let detail: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentBlue)
                    .frame(width: 40, height: 40)
                    .background(Color.accentBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(detail)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary action button

struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview modal

struct WorkoutPreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let session: WorkoutSession
}

struct WorkoutPreviewView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    let item: WorkoutPreviewItem
    @State private var showActive = false

    var store: WorkoutStore { appState.workoutStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 4)

                        ForEach(item.session.exercises) { ex in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ex.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    Text(setSummary(ex))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.begin(item.session)
                    showActive = true
                } label: {
                    Text("Start Workout")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .fullScreenCover(isPresented: $showActive, onDismiss: { dismiss() }) {
                ActiveWorkoutView(session: item.session)
            }
        }
    }

    /// "3 sets · 5 reps · 135 lb" (weight shown only when it's a loaded exercise).
    private func setSummary(_ ex: WorkoutExercise) -> String {
        let sets = ex.sets.count
        var parts = ["\(sets) set\(sets == 1 ? "" : "s")"]
        if let reps = ex.sets.first?.reps { parts.append("\(reps) reps") }
        if let w = ex.sets.first?.weightKg, w > 0 {
            parts.append("\(Int((w / 0.453592).rounded())) lb")
        }
        return parts.joined(separator: " · ")
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
            .background(Color.accentRed.opacity(0.12))
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

// MARK: - History row (shared with WorkoutHistoryView)

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

// MARK: - Shared stat pill (used by WorkoutHistoryView)

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

// MARK: - Custom builder

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
