import SwiftUI

// MARK: - Program List View

struct ProgramView: View {
    @Environment(AppState.self) var appState
    @State private var showNewProgram = false
    @State private var activeSession: WorkoutSession? = nil

    private var store: WorkoutStore { appState.workoutStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Active program card
                        if let active = store.activeProgram {
                            ActiveProgramCard(program: active) {
                                startProgramWorkout(active)
                            }
                            .padding(.horizontal, 16)
                        }

                        // All programs
                        SectionHeader(title: "YOUR PROGRAMS")
                            .padding(.horizontal, 16)

                        ForEach(store.programs) { program in
                            NavigationLink {
                                ProgramDetailView(program: program)
                            } label: {
                                ProgramRowCard(program: program,
                                               isActive: program.isActive) {
                                    store.setActiveProgram(program)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Button {
                            showNewProgram = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentBlue)
                                Text("Create Custom Program")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.accentBlue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.accentBlue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showNewProgram) {
                NewProgramView()
            }
            .sheet(item: $activeSession) { session in
                ActiveWorkoutView(session: session)
            }
        }
    }

    private func startProgramWorkout(_ program: TrainingProgram) {
        if let session = store.startProgramWorkout() {
            activeSession = session
        }
    }
}

// MARK: - Active Program Card

struct ActiveProgramCard: View {
    let program: TrainingProgram
    let onStart: () -> Void
    @Environment(AppState.self) var appState

    private var store: WorkoutStore { appState.workoutStore }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color.accentYellow)
                            .font(.system(size: 12))
                        Text("ACTIVE PROGRAM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.accentYellow)
                            .tracking(1)
                    }
                    Text(program.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text(program.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(program.goal.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentPurple.opacity(0.15))
                    .clipShape(Capsule())
            }

            Divider().background(Color.cardBorder)

            // Next workout
            if let next = program.nextWorkout {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEXT UP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.textTertiary)
                        .tracking(1)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Workout \(next.label) — \(next.name)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text("\(next.exercises.count) exercises")
                                .font(.metricLabel(12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Button {
                            onStart()
                        } label: {
                            Text("Start")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(Color.accentGreen)
                                .clipShape(Capsule())
                        }
                    }

                    // Exercise preview
                    WorkoutExercisePreview(exercises: next.exercises.prefix(4).map(\.exerciseName))
                }
            }

            // Progress through program
            let total = program.workouts.count
            let done = program.currentWorkoutIndex
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < done ? Color.accentGreen : (i == done ? Color.accentBlue : Color.cardBorder))
                        .frame(height: 4)
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentYellow.opacity(0.3), lineWidth: 1)
        )
    }
}

struct WorkoutExercisePreview: View {
    let exercises: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(exercises, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appBackground)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Program Row Card

struct ProgramRowCard: View {
    let program: TrainingProgram
    let isActive: Bool
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Goal icon
            ZStack {
                Circle()
                    .fill(goalColor(program.goal).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: goalIcon(program.goal))
                    .foregroundStyle(goalColor(program.goal))
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(program.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentGreen)
                            .font(.system(size: 13))
                    }
                }
                Text("\(program.workouts.count) workouts · \(program.daysPerWeek)x/week")
                    .font(.metricLabel(12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if !isActive {
                Button("Set Active") {
                    onActivate()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentBlue)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textTertiary)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isActive ? Color.accentGreen.opacity(0.4) : Color.cardBorder, lineWidth: 1)
        )
    }

    private func goalIcon(_ goal: ProgramGoal) -> String {
        switch goal {
        case .strength, .powerlifting: return "dumbbell.fill"
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .endurance, .swim: return "figure.pool.swim"
        case .fat_loss: return "flame.fill"
        case .general: return "heart.fill"
        }
    }

    private func goalColor(_ goal: ProgramGoal) -> Color {
        switch goal {
        case .strength, .powerlifting: return Color.accentBlue
        case .hypertrophy: return Color.accentPurple
        case .endurance, .swim: return Color.accentBlue
        case .fat_loss: return Color.accentOrange
        case .general: return Color.accentGreen
        }
    }
}

// MARK: - Program Detail View

struct ProgramDetailView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    let program: TrainingProgram

    private var store: WorkoutStore { appState.workoutStore }
    @State private var localProgram: TrainingProgram

    init(program: TrainingProgram) {
        self.program = program
        _localProgram = State(initialValue: program)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localProgram.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(localProgram.description)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Text(localProgram.goal.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentPurple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentPurple.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        if !localProgram.isActive {
                            Button {
                                store.setActiveProgram(localProgram)
                                localProgram.isActive = true
                            } label: {
                                Text("Set as Active Program")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.accentBlue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    // Workouts
                    SectionHeader(title: "WORKOUTS").padding(.horizontal, 16)

                    ForEach(localProgram.workouts) { workout in
                        ProgramWorkoutCard(workout: workout,
                                           isCurrent: localProgram.currentWorkoutIndex % max(localProgram.workouts.count, 1) == localProgram.workouts.firstIndex(where: { $0.id == workout.id }) ?? -1)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(localProgram.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Program Workout Card

struct ProgramWorkoutCard: View {
    let workout: ProgramWorkout
    let isCurrent: Bool
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isCurrent ? Color.accentBlue : Color.cardBorder)
                            .frame(width: 34, height: 34)
                        Text(workout.label)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isCurrent ? .white : Color.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(workout.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            if isCurrent {
                                Text("NEXT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.accentBlue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.accentBlue.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(workout.exercises.count) exercises")
                            .font(.metricLabel(12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.textTertiary)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(14)
            }

            // Expanded exercise list
            if isExpanded {
                Divider().background(Color.cardBorder)
                VStack(spacing: 0) {
                    ForEach(workout.exercises) { ex in
                        HStack(spacing: 10) {
                            Text(ex.exerciseName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(ex.equipment.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                            Text("\(ex.rule.sets)×\(ex.rule.minReps)\(ex.rule.minReps != ex.rule.maxReps ? "-\(ex.rule.maxReps)" : "")")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 48, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if ex.id != workout.exercises.last?.id {
                            Divider().padding(.leading, 14).background(Color.cardBorder)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isCurrent ? Color.accentBlue.opacity(0.4) : Color.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - New Program View (basic)

// MARK: - New Program Builder

struct NewProgramView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var goal: ProgramGoal = .strength
    @State private var workouts: [DraftWorkout] = [DraftWorkout(label: "A"), DraftWorkout(label: "B")]
    @State private var editingWorkoutIndex: Int? = nil
    @State private var showExercisePicker = false

    private var store: WorkoutStore { appState.workoutStore }
    private let labels = ["A","B","C","D","E","F","G"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Name & goal
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PROGRAM DETAILS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.textTertiary)
                                .tracking(1)

                            TextField("Program name (e.g. My 5×5)", text: $name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .padding(12)
                                .background(Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            TextField("Description (optional)", text: $description)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textSecondary)
                                .padding(12)
                                .background(Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Picker("Goal", selection: $goal) {
                                ForEach(ProgramGoal.allCases, id: \.self) { g in
                                    Text(g.rawValue).tag(g)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal, 16)

                        // Workout days
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("WORKOUT DAYS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.textTertiary)
                                    .tracking(1)
                                Spacer()
                                if workouts.count < 7 {
                                    Button {
                                        workouts.append(DraftWorkout(label: labels[workouts.count]))
                                    } label: {
                                        Label("Add Day", systemImage: "plus.circle.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.accentBlue)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            ForEach(workouts.indices, id: \.self) { idx in
                                DraftWorkoutCard(
                                    workout: $workouts[idx],
                                    onAddExercise: {
                                        editingWorkoutIndex = idx
                                        showExercisePicker = true
                                    },
                                    onDelete: workouts.count > 1 ? { workouts.remove(at: idx) } : nil
                                )
                                .padding(.horizontal, 16)
                            }
                        }

                        Color.clear.frame(height: 30)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveProgram() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(name.isEmpty ? Color.textTertiary : Color.accentBlue)
                        .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                if let idx = editingWorkoutIndex {
                    ExercisePickerView { def in
                        let pe = ProgramExercise(
                            exerciseName: def.name,
                            equipment: def.primaryEquipment.first ?? .barbell,
                            orderIndex: workouts[idx].exercises.count,
                            rule: def.defaultRule,
                            isSwim: def.isSwim
                        )
                        workouts[idx].exercises.append(pe)
                    }
                }
            }
        }
    }

    private func saveProgram() {
        let programWorkouts = workouts.enumerated().map { idx, draft in
            ProgramWorkout(
                name: draft.name.isEmpty ? "Workout \(draft.label)" : draft.name,
                label: draft.label,
                type: .custom,
                exercises: draft.exercises
            )
        }
        var prog = TrainingProgram(
            name: name,
            description: description,
            daysPerWeek: workouts.count,
            goal: goal
        )
        prog.workouts = programWorkouts
        store.saveProgram(prog)
        dismiss()
    }
}

// MARK: - Draft models (local to builder, not persisted)

struct DraftWorkout {
    var label: String
    var name: String = ""
    var exercises: [ProgramExercise] = []
}

struct DraftWorkoutCard: View {
    @Binding var workout: DraftWorkout
    let onAddExercise: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WORKOUT \(workout.label)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentBlue)
                    .tracking(0.5)
                Spacer()
                if let del = onDelete {
                    Button(action: del) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            TextField("Day name (optional, e.g. Push)", text: $workout.name)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if workout.exercises.isEmpty {
                Text("No exercises yet. Tap below to add.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(workout.exercises.indices, id: \.self) { i in
                    ProgramExerciseRow(exercise: $workout.exercises[i]) {
                        workout.exercises.remove(at: i)
                    }
                }
            }

            Button {
                onAddExercise()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Exercise")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.accentBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
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

struct ProgramExerciseRow: View {
    @Binding var exercise: ProgramExercise
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.exerciseName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 6) {
                    Text(exercise.equipment.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.accentBlue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentBlue.opacity(0.12))
                        .clipShape(Capsule())
                    Text("\(exercise.rule.sets) sets · \(exercise.rule.minReps)–\(exercise.rule.maxReps) reps")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Spacer()
            // Sets stepper
            HStack(spacing: 4) {
                Button {
                    if exercise.rule.sets > 1 { exercise.rule.sets -= 1 }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Color.textTertiary)
                }
                Text("\(exercise.rule.sets)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 20, alignment: .center)
                Button {
                    if exercise.rule.sets < 10 { exercise.rule.sets += 1 }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentBlue)
                }
            }
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.textTertiary)
                    .font(.system(size: 18))
            }
        }
        .padding(10)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
