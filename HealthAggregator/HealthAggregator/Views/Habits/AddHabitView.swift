import SwiftUI

struct AddHabitView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var editing: Habit? = nil

    @State private var name = ""
    @State private var category: HabitCategory = .custom
    @State private var timeSlot: HabitTimeSlot = .anytime
    @State private var selectedIcon = "checkmark.circle.fill"
    @State private var selectedColor = "#6366F1"

    private var store: HabitStore { appState.habitStore }

    private let icons = [
        "checkmark.circle.fill", "pills.fill", "drop.fill", "heart.fill",
        "flame.fill", "moon.stars.fill", "sun.max.fill", "book.fill",
        "figure.mind.and.body", "shower.fill", "leaf.fill", "sparkles",
        "mouth.fill", "wind", "dumbbell.fill", "fork.knife",
        "figure.walk", "brain.head.profile", "figure.flexibility", "cup.and.saucer.fill",
        "bed.double.fill", "alarm.fill", "timer", "person.2.fill"
    ]

    private let colors = [
        "#6366F1", "#A855F7", "#EC4899", "#EF4444",
        "#F97316", "#F59E0B", "#84CC16", "#22C55E",
        "#14B8A6", "#06B6D4", "#3B82F6", "#8B5CF6"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section("Name") {
                        TextField("e.g. Vitamin C, Cold Shower, Floss", text: $name)
                            .foregroundStyle(Color.textPrimary)
                    }
                    .listRowBackground(Color.cardBackground)

                    Section("Category") {
                        Picker("Category", selection: $category) {
                            ForEach(HabitCategory.allCases, id: \.self) { cat in
                                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .foregroundStyle(Color.textPrimary)
                    }
                    .listRowBackground(Color.cardBackground)

                    Section("Time of Day") {
                        Picker("Time", selection: $timeSlot) {
                            ForEach(HabitTimeSlot.allCases, id: \.self) { slot in
                                Text(slot.rawValue).tag(slot)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Color.cardBackground)

                    Section("Color") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(colors, id: \.self) { hex in
                                Button {
                                    selectedColor = hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 36, height: 36)
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.cardBackground)

                    Section("Icon") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColor) : Color.textTertiary)
                                        .frame(width: 40, height: 40)
                                        .background(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.15) : Color.appBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editing == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editing == nil ? "Add" : "Save") {
                        save()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.textTertiary : Color.accentBlue)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: category) { _, cat in
                selectedIcon = cat.icon
                selectedColor = cat.colorHex
            }
            .onAppear {
                if let h = editing {
                    name = h.name
                    category = h.category
                    timeSlot = h.timeSlot
                    selectedIcon = h.icon
                    selectedColor = h.colorHex
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var existing = editing {
            existing.name = trimmed
            existing.category = category
            existing.timeSlot = timeSlot
            existing.icon = selectedIcon
            existing.colorHex = selectedColor
            store.updateHabit(existing)
        } else {
            store.addHabit(Habit(
                name: trimmed,
                category: category,
                icon: selectedIcon,
                colorHex: selectedColor,
                timeSlot: timeSlot
            ))
        }
        dismiss()
    }
}
