import SwiftUI

struct HabitsView: View {
    @Environment(AppState.self) var appState
    @State private var showSetupChat = false
    @State private var showAddHabit = false
    @State private var showEditHabit: Habit? = nil

    private var store: HabitStore { appState.habitStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if store.habits.isEmpty && !store.isSetupComplete {
                    HabitEmptyState {
                        if ClaudeService.shared.hasKey {
                            showSetupChat = true
                        } else {
                            showAddHabit = true
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Completion ring
                            DayCompletionRing(
                                fraction: store.todayFraction,
                                completed: store.todayCompleted,
                                total: store.todayTotal
                            )
                            .padding(.horizontal, 16)

                            // AM section
                            let amHabits = store.habitsForSection(.am)
                            if !amHabits.isEmpty {
                                HabitSection(title: "MORNING", icon: "sun.max.fill", habits: amHabits, slot: .am, store: store)
                                    .padding(.horizontal, 16)
                            }

                            // Anytime section
                            let anytimeHabits = store.habitsForSection(.anytime)
                            if !anytimeHabits.isEmpty {
                                HabitSection(title: "ANYTIME", icon: "checkmark.circle.fill", habits: anytimeHabits, slot: .anytime, store: store)
                                    .padding(.horizontal, 16)
                            }

                            // PM section
                            let pmHabits = store.habitsForSection(.pm)
                            if !pmHabits.isEmpty {
                                HabitSection(title: "EVENING", icon: "moon.stars.fill", habits: pmHabits, slot: .pm, store: store)
                                    .padding(.horizontal, 16)
                            }

                            Color.clear.frame(height: 20)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                AppHeader {
                    Menu {
                        Button {
                            showAddHabit = true
                        } label: {
                            Label("Add Habit", systemImage: "plus.circle")
                        }
                        if ClaudeService.shared.hasKey {
                            Button {
                                showSetupChat = true
                            } label: {
                                Label("AI Setup", systemImage: "sparkles")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.accentBlue)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSetupChat) {
                HabitSetupChatView()
            }
            .sheet(isPresented: $showAddHabit) {
                AddHabitView()
            }
        }
    }
}

// MARK: - Empty State

struct HabitEmptyState: View {
    let onSetup: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentPurple)

            VStack(spacing: 8) {
                Text("Set Up Your Habits")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Chat with your AI wellness coach to build your daily routine — supplements, skincare, dental, hydration, and more.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: onSetup) {
                Label(ClaudeService.shared.hasKey ? "Chat with AI Coach" : "Add Habit Manually",
                      systemImage: ClaudeService.shared.hasKey ? "sparkles" : "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if !ClaudeService.shared.hasKey {
                Text("Add your Anthropic API key in Settings to enable the AI coach.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Day Completion Ring

struct DayCompletionRing: View {
    let fraction: Double
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.cardBorder, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: fraction)

                VStack(spacing: 2) {
                    Text("\(Int(fraction * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                    Text("done")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(motivationText)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(completed) of \(total) habits complete today")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 0.5)
        )
    }

    private var ringColor: Color {
        switch fraction {
        case 1.0:       return Color.accentGreen
        case 0.7...:    return Color.accentBlue
        case 0.4...:    return Color.accentOrange
        default:        return Color.accentPurple
        }
    }

    private var motivationText: String {
        switch fraction {
        case 1.0:   return "Perfect day! 🔥"
        case 0.8...: return "Almost there!"
        case 0.5...: return "Halfway done"
        case 0.0:    return "Let's get started"
        default:     return "Keep going"
        }
    }
}

// MARK: - Habit Section

struct HabitSection: View {
    let title: String
    let icon: String
    let habits: [Habit]
    let slot: HabitTimeSlot
    let store: HabitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .tracking(1)
                Spacer()
                let done = habits.filter { store.isCompleted($0, slot: slot) }.count
                Text("\(done)/\(habits.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }

            VStack(spacing: 1) {
                ForEach(habits) { habit in
                    HabitRow(habit: habit, slot: slot, store: store)
                }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Habit Row

struct HabitRow: View {
    let habit: Habit
    let slot: HabitTimeSlot
    let store: HabitStore
    @State private var bounce = false

    private var isCompleted: Bool { store.isCompleted(habit, slot: slot) }
    private var habitStreak: Int { store.streak(for: habit, slot: slot) }
    private var color: Color { Color(hex: habit.colorHex) }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                bounce = true
                store.toggle(habit, slot: slot)
            }
            HapticsManager.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { bounce = false }
        } label: {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: habit.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isCompleted ? .white : color)
                    .frame(width: 36, height: 36)
                    .background(isCompleted ? color : color.opacity(0.15))
                    .clipShape(Circle())
                    .scaleEffect(bounce ? 1.2 : 1.0)

                // Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isCompleted ? Color.textSecondary : Color.textPrimary)
                        .strikethrough(isCompleted, color: Color.textTertiary)

                    if let group = habit.routineGroup {
                        Text(group)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                // Streak
                if habitStreak > 0 {
                    HStack(spacing: 3) {
                        Text("🔥")
                            .font(.system(size: 11))
                        Text("\(habitStreak)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.accentOrange)
                    }
                }

                // Checkmark
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isCompleted ? color : Color.textTertiary)
                    .scaleEffect(bounce && isCompleted ? 1.3 : 1.0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
