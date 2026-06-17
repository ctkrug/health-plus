import SwiftUI

struct AddHabitView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

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
        "mouth.fill", "wind", "dumbbell.fill", "fork.knife"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section("Name") {
                        TextField("e.g. Vitamin C, Floss, Cold Shower", text: $name)
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
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let habit = Habit(
                            name: name.isEmpty ? "New Habit" : name,
                            category: category,
                            icon: selectedIcon,
                            colorHex: selectedColor,
                            timeSlot: timeSlot
                        )
                        store.addHabit(habit)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.accentBlue)
                }
            }
            .onChange(of: category) { _, cat in
                selectedIcon = cat.icon
                selectedColor = cat.colorHex
            }
        }
    }
}
