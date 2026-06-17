import SwiftUI
import Combine
import ActivityKit

struct ActiveWorkoutView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State var session: WorkoutSession
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var restTimer: Timer? = nil
    @State private var restTimerRunning = false
    @State private var restCountdown: Int = 0
    @State private var showPRBanner: String? = nil
    @State private var showComplete = false
    @State private var showExercisePicker = false
    @State private var showDiscardAlert = false
    @State private var prTimer: Timer? = nil
    @State private var liveActivity = LiveActivityManager()

    private var store: WorkoutStore { appState.workoutStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Timer header
                    WorkoutTimerHeader(
                        name: session.name,
                        elapsed: elapsed,
                        progress: session.progressFraction
                    )

                    // PR banner
                    if let pr = showPRBanner {
                        PRBanner(exerciseName: pr)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(10)
                    }

                    // Rest timer
                    if restTimerRunning {
                        RestTimerBar(countdown: restCountdown) {
                            cancelRestTimer()
                        }
                    }

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach($session.exercises) { $exercise in
                                ExerciseSection(
                                    exercise: $exercise,
                                    session: session,
                                    store: store,
                                    programExercise: activeProgramExercise(for: exercise.name),
                                    onSetLogged: { set in handleSetLogged(set, exercise: exercise) }
                                )
                                .padding(.horizontal, 16)
                            }

                            // Add exercise
                            Button {
                                showExercisePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.accentBlue)
                                    Text("Add Exercise")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.accentBlue)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color.accentBlue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            // Finish button
                            Button {
                                finishWorkout()
                            } label: {
                                Text("Finish Workout")
                                    .font(.system(size: 17, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.accentGreen)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 30)
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDiscardAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Discard Workout", role: .destructive) {
                            discardWorkout()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .alert("Discard Workout?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { discardWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your workout will not be saved.")
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { def in
                    addExercise(def)
                }
            }
            .fullScreenCover(isPresented: $showComplete) {
                WorkoutCompleteView(session: session)
            }
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onChange(of: session) { _, newSession in
            // Keep store.currentSession in sync so the banner re-opens the live session
            store.currentSession = newSession
        }
    }

    // MARK: - Actions

    private func handleSetLogged(_ set: WorkoutSet, exercise: WorkoutExercise) {
        HapticsManager.setLog()
        startRestTimer(seconds: 90)

        // PR check
        if let e1rm = set.estimated1RM,
           store.isPR(exerciseName: exercise.name, estimated1RM: e1rm) {
            showPR(exercise.name)
        }
    }

    private func showPR(_ name: String) {
        withAnimation(.spring(response: 0.4)) {
            showPRBanner = name
        }
        HapticsManager.pr()
        prTimer?.invalidate()
        prTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation { showPRBanner = nil }
        }
    }

    private func startRestTimer(seconds: Int) {
        restCountdown = seconds
        restTimerRunning = true
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if restCountdown > 0 {
                restCountdown -= 1
                updateLiveActivity()
            } else {
                t.invalidate()
                restTimerRunning = false
                HapticsManager.restTimerDone()
                updateLiveActivity()
            }
        }
        appState.notificationService.scheduleRestTimer(seconds: seconds)
    }

    private func cancelRestTimer() {
        restTimer?.invalidate()
        restTimerRunning = false
        appState.notificationService.cancelRestTimer()
    }

    private func startTimer() {
        guard timer == nil else { return }  // prevent duplicate timers on re-appear
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
            updateLiveActivity()
        }
        let firstExercise = session.exercises.first?.name ?? session.name
        liveActivity.startActivity(workoutName: session.name, exerciseName: firstExercise)
    }

    private func stopTimer() {
        timer?.invalidate()
        restTimer?.invalidate()
        prTimer?.invalidate()
    }

    private func finishWorkout() {
        stopTimer()
        liveActivity.end()
        let fromProgram = activeProgramExercise(for: session.exercises.first?.name ?? "") != nil
        store.completeWorkout(session, fromProgram: fromProgram)
        showComplete = true
    }

    private func discardWorkout() {
        stopTimer()
        liveActivity.end()
        store.discardCurrentWorkout()
        dismiss()
    }

    private func updateLiveActivity() {
        let currentExercise = session.exercises.first(where: { !$0.sets.allSatisfy(\.isCompleted) })
            ?? session.exercises.last
        let setsDone = currentExercise?.sets.filter(\.isCompleted).count ?? 0
        let totalSets = currentExercise?.sets.count ?? 0
        liveActivity.update(
            exerciseName: currentExercise?.name ?? session.name,
            setNumber: setsDone + 1,
            totalSets: max(totalSets, 1),
            restSeconds: restTimerRunning ? restCountdown : nil,
            isResting: restTimerRunning,
            elapsed: Int(elapsed)
        )
    }

    private func addExercise(_ def: ExerciseDefinition) {
        var ex = WorkoutExercise(name: def.name, orderIndex: session.exercises.count)
        ex.sets = [WorkoutSet(setNumber: 1, reps: 8)]
        session.exercises.append(ex)
    }

    private func activeProgramExercise(for name: String) -> ProgramExercise? {
        guard let prog = store.activeProgram,
              let pw = prog.nextWorkout else { return nil }
        return pw.exercises.first { $0.exerciseName == name }
    }
}

// MARK: - Timer Header

struct WorkoutTimerHeader: View {
    let name: String
    let elapsed: TimeInterval
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(name.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                    .tracking(1)
                Spacer()
                Text(elapsed.formatted())
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.cardBorder).frame(height: 3)
                    Rectangle().fill(Color.accentBlue).frame(width: geo.size.width * progress, height: 3)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 3)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Rest Timer Bar

struct RestTimerBar: View {
    let countdown: Int
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(Color.accentYellow)
            Text("Rest: \(countdown)s")
                .font(.workoutUI(15))
                .foregroundStyle(Color.accentYellow)
            Spacer()
            Button("Skip", action: onCancel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.accentYellow.opacity(0.1))
    }
}

// MARK: - PR Banner

struct PRBanner: View {
    let exerciseName: String

    var body: some View {
        HStack(spacing: 10) {
            Text("🔥")
            Text("New PR — \(exerciseName)!")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.accentGreen.opacity(0.2))
        .overlay(
            Rectangle()
                .fill(Color.accentGreen)
                .frame(height: 2),
            alignment: .bottom
        )
    }
}

// MARK: - Exercise Section

struct ExerciseSection: View {
    @Binding var exercise: WorkoutExercise
    let session: WorkoutSession
    let store: WorkoutStore
    let programExercise: ProgramExercise?       // nil for freestyle workouts
    let onSetLogged: (WorkoutSet) -> Void

    private var suggestion: ProgressionSuggestion? {
        guard let pe = programExercise else { return nil }
        return store.suggestion(for: exercise.name, rule: pe.rule)
    }

    private var previousBest: String? {
        guard let prev = store.sessions.first(where: { s in s.exercises.contains { $0.name == exercise.name } }),
              let prevEx = prev.exercises.first(where: { $0.name == exercise.name }),
              let bestSet = prevEx.completedSets.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }),
              let w = bestSet.weightKg, let r = bestSet.reps
        else { return nil }
        return "Last: \(String(format: "%.1f", w / 0.453592)) lb × \(r)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    if let prev = previousBest {
                        Text(prev)
                            .font(.metricLabel(12))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                Spacer()

                // Equipment badge
                if let pe = programExercise {
                    Text(pe.equipment.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentBlue.opacity(0.15))
                        .clipShape(Capsule())
                }

                Menu {
                    Button("Add Set") { addSet() }
                    if let sugg = suggestion, sugg.isReadyToProgress {
                        Button("Apply Suggested Weight") { applyProgression() }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Progression suggestion banner
            if let sugg = suggestion {
                ProgressionBadge(suggestion: sugg) {
                    applyProgression()
                }
            }

            // Column headers
            HStack {
                Text("Set").frame(width: 32, alignment: .center)
                Text("Target").frame(maxWidth: .infinity, alignment: .leading)
                Text("Weight").frame(width: 80, alignment: .center)
                Text("Reps").frame(width: 50, alignment: .center)
                Image(systemName: "checkmark").frame(width: 36)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, 4)

            // Sets
            ForEach($exercise.sets) { $workoutSet in
                SetRow(workoutSet: $workoutSet, exercise: exercise, onLog: { onSetLogged(workoutSet) })
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 0.5)
        )
    }

    private func addSet() {
        let newSet = WorkoutSet(
            setNumber: exercise.sets.count + 1,
            weightKg: exercise.sets.last?.weightKg,
            weightUnit: exercise.sets.last?.weightUnit ?? .lbs,
            reps: exercise.sets.last?.reps ?? 8
        )
        exercise.sets.append(newSet)
    }

    private func applyProgression() {
        guard let sugg = suggestion else { return }
        for i in exercise.sets.indices {
            exercise.sets[i].targetWeightKg = sugg.suggestedWeightKg
            exercise.sets[i].weightKg = sugg.suggestedWeightKg
            exercise.sets[i].targetReps = sugg.suggestedReps
            exercise.sets[i].reps = sugg.suggestedReps
        }
        HapticsManager.light()
    }
}

// MARK: - Progression Badge

struct ProgressionBadge: View {
    let suggestion: ProgressionSuggestion
    let onApply: () -> Void

    private var badgeColor: Color {
        switch suggestion.action {
        case .increaseWeight, .increaseReps: return Color.accentGreen
        case .holdSteady: return Color.accentBlue
        case .deload: return Color.accentYellow
        case .firstTime: return Color.textSecondary
        }
    }

    private var icon: String {
        switch suggestion.action {
        case .increaseWeight: return "arrow.up.circle.fill"
        case .increaseReps: return "plus.circle.fill"
        case .holdSteady: return "equal.circle.fill"
        case .deload: return "arrow.down.circle.fill"
        case .firstTime: return "star.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(badgeColor)
                .font(.system(size: 15))
            Text(suggestion.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
            Spacer()
            if suggestion.isReadyToProgress {
                Button("Apply") { onApply() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(badgeColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(badgeColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Set Row

struct SetRow: View {
    @Binding var workoutSet: WorkoutSet
    let exercise: WorkoutExercise
    let onLog: () -> Void

    @State private var weightText = ""
    @State private var repsText = ""
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    var isActive: Bool { !workoutSet.isCompleted }
    var bgColor: Color { workoutSet.isCompleted ? Color.accentGreen.opacity(0.15) : Color.cardBackground }

    var body: some View {
        HStack(spacing: 6) {
            // Set number
            Text(workoutSet.isPR ? "🔥" : "\(workoutSet.setNumber)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(workoutSet.isPR ? Color.accentYellow : Color.textSecondary)
                .frame(width: 32, alignment: .center)

            // Previous
            Text(previousLabel)
                .font(.metricLabel(12))
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // Weight input
            HStack(spacing: 4) {
                TextField("lbs", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .focused($weightFocused)
                    .frame(width: 52)
                    .padding(.vertical, 6)
                    .background(Color.cardBorder.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("lb").font(.metricLabel(10)).foregroundStyle(Color.textTertiary)
            }
            .frame(width: 80)

            // Reps input
            TextField("reps", text: $repsText)
                .keyboardType(.numberPad)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .focused($repsFocused)
                .frame(width: 50)
                .padding(.vertical, 6)
                .background(Color.cardBorder.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Log button
            Button {
                logSet()
            } label: {
                Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(workoutSet.isCompleted ? Color.accentGreen : Color.textTertiary)
            }
            .frame(width: 36)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(.spring(response: 0.3), value: workoutSet.isCompleted)
        .onAppear {
            // Only initialize from model if fields are empty — prevents LazyVStack re-appears
            // from clobbering text the user has already typed but not yet logged
            if weightText.isEmpty {
                weightText = workoutSet.weightKg.map { String(format: "%.1f", $0 / 0.453592) } ?? ""
            }
            if repsText.isEmpty {
                repsText = workoutSet.reps.map { "\($0)" } ?? ""
            }
        }
    }

    private var previousLabel: String {
        guard let w = workoutSet.targetWeightKg, let r = workoutSet.targetReps else { return "—" }
        return "\(String(format: "%.1f", w / 0.453592)) × \(r)"
    }

    private func logSet() {
        // Parse fields
        if let lbs = Double(weightText) { workoutSet.weightKg = lbs * 0.453592 }
        if let r = Int(repsText) { workoutSet.reps = r }
        workoutSet.isCompleted.toggle()
        workoutSet.completedAt = workoutSet.isCompleted ? Date() : nil
        if workoutSet.isCompleted { onLog() }
    }
}

// MARK: - Exercise Picker

struct ExercisePickerView: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (ExerciseDefinition) -> Void

    @State private var search = ""
    @State private var selectedCategory: ExerciseCategory? = nil

    private var filtered: [ExerciseDefinition] {
        var results = ExerciseLibrary.search(search)
        if let cat = selectedCategory { results = results.filter { $0.category == cat } }
        return results
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Category chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryChip(label: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                                CategoryChip(label: cat.rawValue, isSelected: selectedCategory == cat) {
                                    selectedCategory = cat
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    List(filtered) { def in
                        Button {
                            onSelect(def)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(def.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                if !def.muscleGroups.isEmpty {
                                    Text(def.muscleGroups.joined(separator: ", "))
                                        .font(.metricLabel(12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentBlue : Color.cardBackground)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.accentBlue : Color.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - TimeInterval formatting

extension TimeInterval {
    func formatted() -> String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
