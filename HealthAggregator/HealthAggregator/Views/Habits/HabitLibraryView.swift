import SwiftUI

struct HabitLibraryView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: HabitCategory? = nil
    @State private var showCustom = false

    private var store: HabitStore { appState.habitStore }

    private var displayedPresets: [PresetHabit] {
        if let cat = selectedCategory {
            return HabitLibrary.presets(for: cat)
        }
        return HabitLibrary.presets
    }

    private func isAdded(_ preset: PresetHabit) -> Bool {
        store.habits.contains { $0.name == preset.name }
    }

    private func toggle(_ preset: PresetHabit) {
        if isAdded(preset) {
            if let habit = store.habits.first(where: { $0.name == preset.name }) {
                store.deleteHabit(habit)
            }
        } else {
            store.addHabit(preset.toHabit())
            HapticsManager.light()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Category filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            LibraryChip(title: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(HabitCategory.libraryOrder, id: \.self) { cat in
                                LibraryChip(
                                    title: cat.rawValue,
                                    icon: cat.icon,
                                    color: Color(hex: cat.colorHex),
                                    isSelected: selectedCategory == cat
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = selectedCategory == cat ? nil : cat
                                    }
                                    HapticsManager.selection()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Added count bar
                    if !store.habits.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.accentGreen)
                            Text("\(store.habits.count) habit\(store.habits.count == 1 ? "" : "s") added")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    // Preset list
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(displayedPresets) { preset in
                                LibraryPresetRow(preset: preset, isAdded: isAdded(preset)) {
                                    toggle(preset)
                                }
                            }
                        }
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.cardBorder, lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)

                        // Custom habit button
                        Button {
                            showCustom = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.accentBlue)
                                Text("Add a custom habit")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.accentBlue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.cardBorder, lineWidth: 0.5)
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Habit Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentBlue)
                }
            }
            .sheet(isPresented: $showCustom) {
                AddHabitView()
            }
        }
    }
}

// MARK: - Library Chip

struct LibraryChip: View {
    let title: String
    var icon: String? = nil
    var color: Color = .accentBlue
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? color : Color.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color.cardBorder, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Library Preset Row

struct LibraryPresetRow: View {
    let preset: PresetHabit
    let isAdded: Bool
    let onToggle: () -> Void

    @State private var popped = false

    private var color: Color { Color(hex: preset.colorHex) }

    var body: some View {
        Button {
            if !isAdded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { popped = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { popped = false }
            }
            onToggle()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: preset.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isAdded ? .white : color)
                    .frame(width: 36, height: 36)
                    .background(isAdded ? color : color.opacity(0.15))
                    .clipShape(Circle())
                    .scaleEffect(popped ? 1.25 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    HStack(spacing: 4) {
                        Text(preset.category.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                        Text(preset.timeSlot.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isAdded ? Color.accentGreen : Color.textTertiary)
                    .animation(.spring(response: 0.3), value: isAdded)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
