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
    @State private var restTimerLabel: String = "Rest"
    @State private var showPRBanner: String? = nil
    @State private var showComplete = false
    @State private var showExercisePicker = false
    @State private var showDiscardAlert = false
    @State private var showFinishConfirm = false
    @State private var restTimerEndDate: Date? = nil
    @State private var prTimer: Timer? = nil
    @State private var liveActivity = LiveActivityManager()
    @State private var supersetPickerIdx: Int? = nil
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 180

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
                        RestTimerBar(label: restTimerLabel, countdown: restCountdown) {
                            cancelRestTimer()
                        }
                    }

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach($session.exercises.indices, id: \.self) { idx in
                                let exercise = session.exercises[idx]
                                let nextIsSupersetPartner: Bool = {
                                    guard let gid = exercise.supersetGroupID,
                                          idx + 1 < session.exercises.count
                                    else { return false }
                                    return session.exercises[idx + 1].supersetGroupID == gid
                                }()

                                ExerciseSection(
                                    exercise: $session.exercises[idx],
                                    session: session,
                                    store: store,
                                    programExercise: activeProgramExercise(for: exercise.name),
                                    onSetLogged: { set in handleSetLogged(set, exercise: exercise) },
                                    onPairSuperset: { supersetPickerIdx = idx },
                                    onUnpairSuperset: { unpairExercise(at: idx) }
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                                if nextIsSupersetPartner {
                                    HStack(spacing: 6) {
                                        Rectangle()
                                            .fill(Color.accentGreen.opacity(0.35))
                                            .frame(width: 2)
                                            .frame(height: 20)
                                            .padding(.leading, 30)
                                        Text("SUPERSET")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.accentGreen)
                                            .tracking(1.2)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                } else {
                                    Spacer().frame(height: 0)
                                }
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
                                showFinishConfirm = true
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
            .sheet(isPresented: Binding(
                get: { supersetPickerIdx != nil },
                set: { if !$0 { supersetPickerIdx = nil } }
            )) {
                if let idx = supersetPickerIdx {
                    WorkoutSupersetPickerSheet(session: $session, sourceIdx: idx) { targetIdx in
                        pairExercises(sourceIdx: idx, targetIdx: targetIdx)
                        supersetPickerIdx = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showComplete, onDismiss: {
                dismiss()   // close ActiveWorkoutView once the summary is dismissed
            }) {
                WorkoutCompleteView(session: session)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                elapsed = Date().timeIntervalSince(session.startDate)
                if let endDate = restTimerEndDate {
                    let remaining = Int(endDate.timeIntervalSinceNow)
                    if remaining <= 0 {
                        restTimerRunning = false
                        restTimerEndDate = nil
                    } else {
                        restCountdown = remaining
                    }
                }
            }
            .confirmationDialog("Finish this workout?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                Button("Finish Workout") { finishWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(session.completedSets) sets completed · \(Int(elapsed / 60))m")
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

        // PR check
        if let e1rm = set.estimated1RM,
           store.isPR(exerciseName: exercise.name, estimated1RM: e1rm) {
            showPR(exercise.name)
        }

        // Superset-aware rest: after logging A, go straight to B (short transition).
        // Only start the full rest after both exercises have completed this round.
        if exercise.isSuperset,
           let gid = exercise.supersetGroupID,
           let partner = session.exercises.first(where: { $0.supersetGroupID == gid && $0.id != exercise.id }) {
            let thisDone = session.exercises.first(where: { $0.id == exercise.id })?.sets.filter(\.isCompleted).count ?? 0
            let partnerDone = partner.sets.filter(\.isCompleted).count
            if partnerDone < thisDone {
                startRestTimer(seconds: 20, label: "→ \(partner.name)")
            } else {
                startRestTimer(seconds: defaultRestSeconds, label: "Rest")
            }
        } else {
            startRestTimer(seconds: defaultRestSeconds, label: "Rest")
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

    private func startRestTimer(seconds: Int, label: String = "Rest") {
        restTimerEndDate = Date().addingTimeInterval(Double(seconds))
        restCountdown = seconds
        restTimerLabel = label
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
        restTimerEndDate = nil
        appState.notificationService.cancelRestTimer()
    }

    private func startTimer() {
        guard timer == nil else { return }  // prevent duplicate timers on re-appear
        // Derive elapsed from session start so re-appearing after backgrounding is accurate
        elapsed = Date().timeIntervalSince(session.startDate)
        let workoutTick = Timer(timeInterval: 1, repeats: true) { [self] _ in
            elapsed += 1
            updateLiveActivity()
        }
        RunLoop.main.add(workoutTick, forMode: .common)
        timer = workoutTick
        let firstExercise = session.exercises.first?.name ?? session.name
        liveActivity.startActivity(workoutName: session.name, exerciseName: firstExercise)
    }

    private func stopTimer() {
        timer?.invalidate();     timer = nil
        restTimer?.invalidate(); restTimer = nil
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

    private func unpairExercise(at idx: Int) {
        guard let gid = session.exercises[idx].supersetGroupID else { return }
        for i in session.exercises.indices where session.exercises[i].supersetGroupID == gid {
            session.exercises[i].supersetGroupID = nil
            session.exercises[i].isSuperset = false
        }
        HapticsManager.light()
    }

    private func pairExercises(sourceIdx: Int, targetIdx: Int) {
        // Remove existing pairings for both exercises
        for gid in [session.exercises[sourceIdx].supersetGroupID,
                    session.exercises[targetIdx].supersetGroupID].compactMap({ $0 }) {
            for i in session.exercises.indices where session.exercises[i].supersetGroupID == gid {
                session.exercises[i].supersetGroupID = nil
                session.exercises[i].isSuperset = false
            }
        }
        let newID = UUID()
        session.exercises[sourceIdx].supersetGroupID = newID
        session.exercises[sourceIdx].isSuperset = true
        session.exercises[targetIdx].supersetGroupID = newID
        session.exercises[targetIdx].isSuperset = true
        HapticsManager.light()
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
    let label: String
    let countdown: Int
    let onCancel: () -> Void

    private var isTransition: Bool { label.hasPrefix("→") }

    var body: some View {
        HStack {
            Image(systemName: isTransition ? "arrow.right.circle.fill" : "timer")
                .foregroundStyle(isTransition ? Color.accentGreen : Color.accentYellow)
            Text("\(label): \(countdown)s")
                .font(.workoutUI(15))
                .foregroundStyle(isTransition ? Color.accentGreen : Color.accentYellow)
            Spacer()
            Button("Skip", action: onCancel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(isTransition ? Color.accentGreen.opacity(0.08) : Color.accentYellow.opacity(0.1))
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
    var onPairSuperset: (() -> Void)? = nil
    var onUnpairSuperset: (() -> Void)? = nil

    private var suggestion: ProgressionSuggestion? {
        // Program workouts use the program's rule; template workouts fall back to the
        // rule derived from the template exercise's sets/reps (so every workout gets
        // progression guidance regardless of how it was started).
        guard let rule = programExercise?.rule ?? exercise.progressionRule else { return nil }
        return store.suggestion(for: exercise.name, rule: rule)
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

                // Superset badge (tap to unpair)
                if exercise.isSuperset {
                    Button { onUnpairSuperset?() } label: {
                        Label("SS", systemImage: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

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
                    Divider()
                    if exercise.isSuperset {
                        Button("Remove from Superset", role: .destructive) { onUnpairSuperset?() }
                    } else {
                        Button("Pair as Superset...") { onPairSuperset?() }
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

    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"
    private var unit: WeightUnit { weightUnitRaw == "kg" ? .kg : .lbs }

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
                TextField(unit.rawValue, text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .focused($weightFocused)
                    .frame(width: 52)
                    .padding(.vertical, 6)
                    .background(Color.cardBorder.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(unit.rawValue).font(.metricLabel(10)).foregroundStyle(Color.textTertiary)
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
                weightText = workoutSet.weightKg.map { String(format: "%.1f", $0 / unit.multiplierToKg) } ?? ""
            }
            if repsText.isEmpty {
                repsText = workoutSet.reps.map { "\($0)" } ?? ""
            }
        }
    }

    private var previousLabel: String {
        guard let w = workoutSet.targetWeightKg, let r = workoutSet.targetReps else { return "—" }
        return "\(String(format: "%.1f", w / unit.multiplierToKg)) × \(r)"
    }

    private func logSet() {
        // Parse fields — convert from the user's preferred unit to kg for storage
        if let entered = Double(weightText) {
            workoutSet.weightKg = entered * unit.multiplierToKg
            workoutSet.weightUnit = unit
        }
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

// MARK: - In-workout superset picker

struct WorkoutSupersetPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var session: WorkoutSession
    let sourceIdx: Int
    let onPair: (Int) -> Void

    private var sourceName: String { session.exercises[sourceIdx].name }

    struct Option: Identifiable {
        let id: Int
        let name: String
        let compat: SupersetEngine.SupersetCompatibility
        let isCurrentPartner: Bool
    }

    private var options: [Option] {
        let sourceGID = session.exercises[sourceIdx].supersetGroupID
        return session.exercises.indices
            .filter { $0 != sourceIdx }
            .map { idx -> Option in
                let ex = session.exercises[idx]
                let compat = SupersetEngine.compatibility(a: sourceName, b: ex.name)
                let isPartner = sourceGID != nil && ex.supersetGroupID == sourceGID
                return Option(id: idx, name: ex.name, compat: compat, isCurrentPartner: isPartner)
            }
            .sorted { $0.compat.score > $1.compat.score }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.accentGreen)
                            Text("Pair with \(sourceName)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                                .multilineTextAlignment(.center)
                            Text("Antagonist pairs allow one muscle to rest while the other works — expect 5–15% more reps on the second exercise.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 20)

                        if options.isEmpty {
                            Text("Add more exercises to create a superset.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textSecondary)
                                .padding(32)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(options) { opt in
                                    SupersetPickerRow(opt: opt, sourceName: sourceName) {
                                        onPair(opt.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Pair Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}

private struct SupersetPickerRow: View {
    let opt: WorkoutSupersetPickerSheet.Option
    let sourceName: String
    let onPair: () -> Void

    private var qColor: Color {
        guard let q = opt.compat.quality else { return .accentRed }
        return Color(hex: q.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Quality label + pairing reason
            HStack {
                Text((opt.compat.quality?.label ?? "Conflict").uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(qColor)
                    .tracking(0.8)
                Text("· \(opt.compat.label)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                if opt.isCurrentPartner {
                    Label("Paired", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentGreen)
                }
            }

            // Exercise pills
            HStack(spacing: 0) {
                Text(sourceName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(qColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: .infinity)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(qColor)
                    .padding(.horizontal, 8)
                Text(opt.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(qColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: .infinity)
            }

            // Warning/description + pair button
            HStack(alignment: .bottom, spacing: 12) {
                if let w = opt.compat.warning {
                    HStack(spacing: 4) {
                        Image(systemName: opt.compat.quality == nil ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(opt.compat.quality == nil ? Color.accentRed : Color.accentYellow)
                        Text(w)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let q = opt.compat.quality {
                    Text(q.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if !opt.isCurrentPartner {
                    Button(opt.compat.quality == nil ? "Pair Anyway" : "Pair Together") { onPair() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(qColor)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    opt.isCurrentPartner ? Color.accentGreen.opacity(0.6) :
                    (opt.compat.quality == nil ? Color.accentRed.opacity(0.3) : Color.cardBorder),
                    lineWidth: opt.isCurrentPartner ? 1.5 : 0.5
                )
        )
    }
}
