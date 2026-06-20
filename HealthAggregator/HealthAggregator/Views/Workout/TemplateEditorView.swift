import SwiftUI

struct TemplateEditorView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var template: WorkoutTemplate
    @State private var showExercisePicker = false

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
                            ExerciseEditorRow(exercise: $ex)
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

    private var weightLbs: Double {
        guard let kg = exercise.defaultWeightKg else { return 0 }
        return (kg / 0.453592).rounded()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Exercise name", text: $exercise.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

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
