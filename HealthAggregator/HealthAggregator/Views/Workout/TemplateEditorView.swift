import SwiftUI

struct TemplateEditorView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var template: WorkoutTemplate
    @State private var showExercisePicker = false
    @State private var showSupersetSheet = false

    private var supersetRecommendations: [SupersetPair] {
        SupersetEngine.recommendations(for: template.exercises)
    }

    @AppStorage("defaultSets") private var defaultSets = 3
    @AppStorage("defaultMinReps") private var defaultMinReps = 8
    @AppStorage("defaultMaxReps") private var defaultMaxReps = 12

    init(template: WorkoutTemplate) {
        _template = State(initialValue: template)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section("Name & Type") {
                        TextField("Workout name", text: $template.name)
                            .foregroundStyle(Color.textPrimary)
                            .listRowBackground(Color.cardBackground)
                        Picker("Type", selection: $template.type) {
                            ForEach(WorkoutType.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .foregroundStyle(Color.textPrimary)
                        .listRowBackground(Color.cardBackground)
                    }

                    Section {
                        ForEach($template.exercises) { $ex in
                            ExerciseEditorRow(exercise: $ex, allExercises: template.exercises)
                                .listRowBackground(Color.cardBackground)
                        }
                        .onDelete { template.exercises.remove(atOffsets: $0) }
                        .onMove { from, to in
                            template.exercises.move(fromOffsets: from, toOffset: to)
                            for i in template.exercises.indices { template.exercises[i].orderIndex = i }
                        }
                        Button {
                            showExercisePicker = true
                        } label: {
                            Label("Add Exercise", systemImage: "plus.circle.fill")
                                .foregroundStyle(Color.accentBlue)
                        }
                        .listRowBackground(Color.cardBackground)
                    } header: {
                        Text("Exercises")
                    } footer: {
                        Text("Swipe left to delete · drag to reorder")
                            .font(.system(size: 11))
                    }

                    if !supersetRecommendations.isEmpty {
                        Section {
                            Button {
                                showSupersetSheet = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.accentGreen)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Suggest Supersets")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.textPrimary)
                                        Text("\(supersetRecommendations.count) smart pair\(supersetRecommendations.count == 1 ? "" : "s") found")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.textTertiary)
                                }
                            }
                            .listRowBackground(Color.cardBackground)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(Color.accentBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.workoutStore.saveTemplate(template)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .disabled(template.name.isEmpty)
                }
            }
            .sheet(isPresented: $showSupersetSheet) {
                SupersetRecommendationsSheet(exercises: $template.exercises,
                                             pairs: supersetRecommendations)
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { def in
                    var ex = TemplateExercise(
                        name: def.name,
                        orderIndex: template.exercises.count,
                        defaultSets: defaultSets,
                        defaultReps: defaultMinReps,
                        maxReps: defaultMaxReps
                    )
                    ex.muscleGroups = def.muscleGroups
                    template.exercises.append(ex)
                }
            }
        }
    }
}

// MARK: - Exercise Editor Row

struct ExerciseEditorRow: View {
    @Binding var exercise: TemplateExercise
    var allExercises: [TemplateExercise] = []

    private var weightLbs: Double {
        guard let kg = exercise.defaultWeightKg else { return 0 }
        return (kg / 0.453592).rounded()
    }

    private var supersetPartner: String? {
        guard let gid = exercise.supersetGroupID else { return nil }
        return allExercises.first(where: { $0.id != exercise.id && $0.supersetGroupID == gid })?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Exercise name", text: $exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                if let partner = supersetPartner {
                    Button {
                        exercise.supersetGroupID = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 9, weight: .bold))
                            Text("SS")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Paired with \(partner) — tap to unpair")
                }
            }

            HStack(spacing: 0) {
                CounterField(
                    label: "Sets",
                    value: $exercise.defaultSets,
                    range: 1...8
                )

                Divider().frame(height: 36).padding(.horizontal, 8)

                CounterField(
                    label: "Min",
                    value: Binding(
                        get: { exercise.defaultReps ?? 8 },
                        set: { exercise.defaultReps = $0 }
                    ),
                    range: 1...50
                )

                Divider().frame(height: 36).padding(.horizontal, 8)

                CounterField(
                    label: "Max",
                    value: Binding(
                        get: { exercise.maxReps ?? exercise.defaultReps ?? 12 },
                        set: { exercise.maxReps = $0 }
                    ),
                    range: 1...50
                )

                Divider().frame(height: 36).padding(.horizontal, 8)

                WeightField(
                    label: "Weight (lb)",
                    weightLbs: weightLbs,
                    onChange: { lbs in
                        exercise.defaultWeightKg = lbs > 0 ? lbs * 0.453592 : nil
                        exercise.defaultWeightUnit = .lbs
                    }
                )
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Counter Field (sets / reps)

private struct CounterField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: 6) {
                Button {
                    if value > range.lowerBound { value -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(Color.appBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(value)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(minWidth: 20, alignment: .center)

                Button {
                    if value < range.upperBound { value += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(Color.appBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Superset Recommendations Sheet

struct SupersetRecommendationsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var exercises: [TemplateExercise]
    let pairs: [SupersetPair]

    // Tracks which pair IDs have been applied this session
    @State private var appliedPairIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        // Header blurb
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.accentGreen)
                            Text("Smart Superset Pairs")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            Text("Antagonist pairs let one muscle rest while the other works — you'll get 5–15% more reps on the second exercise.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 20)

                        VStack(spacing: 12) {
                            ForEach(pairs) { pair in
                                SupersetPairCard(
                                    pair: pair,
                                    isApplied: appliedPairIDs.contains(pair.id)
                                ) {
                                    applyPair(pair)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Supersets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    private func applyPair(_ pair: SupersetPair) {
        let groupID = UUID()
        for i in exercises.indices {
            if exercises[i].id == pair.a.id || exercises[i].id == pair.b.id {
                exercises[i].supersetGroupID = groupID
            }
        }
        appliedPairIDs.insert(pair.id)
    }
}

struct SupersetPairCard: View {
    let pair: SupersetPair
    let isApplied: Bool
    let onApply: () -> Void

    var qualityColor: Color {
        Color(hex: pair.quality.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quality badge + label
            HStack {
                Text(pair.quality.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(qualityColor)
                    .tracking(0.8)
                Text("· \(pair.label)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Spacer()
            }

            // Exercise pair
            HStack(spacing: 0) {
                ExercisePill(name: pair.a.name, color: qualityColor)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(qualityColor)
                    .padding(.horizontal, 8)
                ExercisePill(name: pair.b.name, color: qualityColor)
            }

            // Description + apply
            HStack(alignment: .bottom) {
                Text(pair.quality.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                if isApplied {
                    Label("Paired", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentGreen)
                } else {
                    Button(action: onApply) {
                        Text("Pair Together")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(qualityColor)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isApplied ? Color.accentGreen.opacity(0.5) : Color.cardBorder, lineWidth: isApplied ? 1.5 : 0.5)
        )
    }
}

private struct ExercisePill: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Weight Field

private struct WeightField: View {
    let label: String
    let weightLbs: Double
    let onChange: (Double) -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textTertiary)
            TextField("—", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(minWidth: 50)
                .focused($focused)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused {
                        let parsed = Double(text) ?? 0
                        onChange(parsed)
                        text = parsed > 0 ? String(Int(parsed)) : ""
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            text = weightLbs > 0 ? String(Int(weightLbs)) : ""
        }
    }
}
