import SwiftUI

struct HabitsView: View {
    @Environment(AppState.self) var appState
    @State private var showSetupChat = false
    @State private var showAddHabit = false
    @State private var showLibrary = false
    @State private var editingHabit: Habit? = nil

    private var store: HabitStore { appState.habitStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if store.habits.isEmpty {
                    HabitEmptyState(
                        onLibrary: { showLibrary = true },
                        onAICoach: { showSetupChat = true },
                        onCustom:  { showAddHabit = true }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            DayCompletionRing(
                                fraction: store.todayFraction,
                                completed: store.todayCompleted,
                                total: store.todayTotal
                            )
                            .padding(.horizontal, 16)

                            let amHabits = store.habitsForSection(.am)
                            if !amHabits.isEmpty {
                                HabitSection(title: "MORNING", icon: "sunrise.fill", habits: amHabits, slot: .am, store: store, onEdit: { editingHabit = $0 })
                                    .padding(.horizontal, 16)
                            }

                            let anytimeHabits = store.habitsForSection(.anytime)
                            if !anytimeHabits.isEmpty {
                                HabitSection(title: "ANYTIME", icon: "checkmark.circle.fill", habits: anytimeHabits, slot: .anytime, store: store, onEdit: { editingHabit = $0 })
                                    .padding(.horizontal, 16)
                            }

                            let pmHabits = store.habitsForSection(.pm)
                            if !pmHabits.isEmpty {
                                HabitSection(title: "EVENING", icon: "moon.fill", habits: pmHabits, slot: .pm, store: store, onEdit: { editingHabit = $0 })
                                    .padding(.horizontal, 16)
                            }

                            Color.clear.frame(height: 20)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            // Milestone celebration
            .overlay {
                if let event = store.pendingMilestone {
                    MilestoneCelebrationView(event: event) {
                        store.pendingMilestone = nil
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .zIndex(100)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.pendingMilestone)
            .overlay(alignment: .bottomTrailing) {
                if !store.habits.isEmpty {
                    Menu {
                        Button { showLibrary = true } label: {
                            Label("Browse Library", systemImage: "square.grid.2x2.fill")
                        }
                        Button { showAddHabit = true } label: {
                            Label("Add Custom", systemImage: "plus.circle")
                        }
                        if ClaudeService.shared.hasKey {
                            Button { showSetupChat = true } label: {
                                Label("AI Setup", systemImage: "sparkles")
                            }
                        }
                    } label: {
                        Image(systemName: "plus").fabStyle()
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 14)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                AppHeader()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSetupChat) { HabitSetupChatView() }
            .sheet(isPresented: $showAddHabit) { AddHabitView() }
            .sheet(isPresented: $showLibrary) { HabitLibraryView() }
            .sheet(item: $editingHabit) { habit in AddHabitView(editing: habit) }
        }
    }
}

// MARK: - Milestone Celebration

struct MilestoneCelebrationView: View {
    let event: HabitMilestoneEvent
    let onDismiss: () -> Void

    @State private var appeared = false
    private var color: Color { Color(hex: event.habit.colorHex) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 22) {
                Text(HabitMilestone.emoji(for: event.count))
                    .font(.system(size: 72))
                    .scaleEffect(appeared ? 1.0 : 0.3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.45), value: appeared)

                VStack(spacing: 8) {
                    Text(HabitMilestone.title(for: event.count))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text(event.habit.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)

                    Text(HabitMilestone.message(for: event.count))
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                }

                Button {
                    HapticsManager.light()
                    onDismiss()
                } label: {
                    Text("Keep Going")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(32)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .scaleEffect(appeared ? 1.0 : 0.75)
            .opacity(appeared ? 1.0 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)
        }
        .onAppear {
            HapticsManager.celebration()
            appeared = true
        }
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            onDismiss()
        }
    }
}

// MARK: - Empty State

struct HabitEmptyState: View {
    let onLibrary: () -> Void
    let onAICoach: () -> Void
    let onCustom: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.accentBlue)
                        .padding(.top, 24)

                    Text("Build Your Daily Ritual")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("80+ preset habits across supplements,\nmorning routines, fitness & more.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    // Library card
                    Button(action: onLibrary) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.accentBlue.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.accentBlue)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Browse Habit Library")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text("Tap to add — supplements, skincare,\nfitness, mindfulness & more")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(16)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.accentBlue.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // AI Coach card (if available)
                    if ClaudeService.shared.hasKey {
                        Button(action: onAICoach) {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.accentPurple.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.accentPurple)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("AI Coach Setup")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    Text("Chat to get a personalized routine\nbuilt for you in minutes")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .padding(16)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.accentPurple.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)

                Button(action: onCustom) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Add a custom habit")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                .padding(.bottom, 20)
            }
        }
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
        case 1.0:    return Color.accentGreen
        case 0.7...: return Color.accentBlue
        case 0.4...: return Color.accentOrange
        default:     return Color.accentPurple
        }
    }

    private var motivationText: String {
        switch fraction {
        case 1.0:    return "Perfect day! 🔥"
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
    var onEdit: ((Habit) -> Void)? = nil

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
                    HabitRow(habit: habit, slot: slot, store: store, onEdit: { onEdit?(habit) })
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
    var onEdit: (() -> Void)? = nil

    @State private var bounce = false

    private var isCompleted: Bool { store.isCompleted(habit, slot: slot) }
    private var habitStreak: Int { store.streak(for: habit, slot: slot) }
    private var totalDone: Int { store.totalCompletions(for: habit) }
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
                Image(systemName: habit.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isCompleted ? .white : color)
                    .frame(width: 36, height: 36)
                    .background(isCompleted ? color : color.opacity(0.15))
                    .clipShape(Circle())
                    .scaleEffect(bounce ? 1.2 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isCompleted ? Color.textSecondary : Color.textPrimary)
                        .strikethrough(isCompleted, color: Color.textTertiary)

                    HStack(spacing: 6) {
                        if let group = habit.routineGroup {
                            Text(group)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        if totalDone >= 5 {
                            Text("\(totalDone)×")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }

                Spacer()

                if habitStreak > 1 {
                    HStack(spacing: 3) {
                        Text("🔥")
                            .font(.system(size: 11))
                        Text("\(habitStreak)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.accentOrange)
                    }
                }

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
        .contextMenu {
            Button { onEdit?() } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                store.deleteHabit(habit)
                HapticsManager.medium()
            } label: {
                Label("Delete Habit", systemImage: "trash")
            }
        }
    }
}
