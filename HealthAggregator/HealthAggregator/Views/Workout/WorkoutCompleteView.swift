import SwiftUI

struct WorkoutCompleteView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    let session: WorkoutSession

    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.7
    @State private var opacity: CGFloat = 0

    private var store: WorkoutStore { appState.workoutStore }
    private var streak: WorkoutStreak { store.streak }
    private var weekSessions: [WorkoutSession] { store.sessionsThisWeek() }
    private var newPRs: [PersonalRecord] {
        store.personalRecords.values.filter { $0.sessionID == session.id }.sorted { $0.estimated1RM > $1.estimated1RM }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showConfetti { ConfettiView() }

            ScrollView {
                VStack(spacing: 28) {
                    // Checkmark hero
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentGreen.opacity(0.2))
                                .frame(width: 100, height: 100)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.accentGreen)
                        }
                        .scaleEffect(scale)
                        .opacity(opacity)

                        Text("Workout Complete!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text(session.startDate, style: .date)
                            .font(.metricLabel(14))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 40)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        CompleteStatCard(label: "Duration", value: formatDuration(session.duration), icon: "clock.fill", color: .accentBlue)
                        CompleteStatCard(label: "Exercises", value: "\(session.exercises.count)", icon: "dumbbell.fill", color: .accentPurple)
                        CompleteStatCard(label: "Total Sets", value: "\(session.completedSets)", icon: "checkmark.square.fill", color: .accentGreen)
                        CompleteStatCard(label: "Volume", value: "\(Int(session.totalVolumeKg / 0.453592).formatted()) lb", icon: "scalemass.fill", color: .accentOrange)
                    }
                    .padding(.horizontal, 20)

                    // Streak
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.accentYellow)
                        Text("\(streak.currentDays)-day streak!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text("🔥")
                    }
                    .padding(16)
                    .background(Color.accentYellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)

                    // New PRs
                    if !newPRs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("New PRs")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, 20)

                            ForEach(newPRs) { pr in
                                HStack {
                                    Text("🔥 \(pr.exerciseName)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Text("\(String(format: "%.1f", pr.weightKg / 0.453592)) lb × \(pr.reps)")
                                        .font(.metricLabel(14))
                                        .foregroundStyle(Color.accentYellow)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    // Exercise summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercises")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 20)

                        ForEach(session.exercises) { exercise in
                            ExerciseSummaryRow(exercise: exercise)
                                .padding(.horizontal, 20)
                        }
                    }

                    // Done button
                    Button {
                        Task {
                            try? await appState.healthKitService.writeWorkout(session)
                        }
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentGreen)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
                HapticsManager.workoutComplete()
            }
        }
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        let minutes = Int(d / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

struct CompleteStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
            Text(value)
                .font(.metric(22))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.metricLabel(12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
    }
}

struct ExerciseSummaryRow: View {
    let exercise: WorkoutExercise

    var body: some View {
        HStack {
            Text(exercise.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text("\(exercise.completedSets.count) sets")
                .font(.metricLabel(13))
                .foregroundStyle(Color.textSecondary)
            if exercise.totalVolume > 0 {
                Text("· \(Int(exercise.totalVolume / 0.453592).formatted()) lb")
                    .font(.metricLabel(13))
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let colors: [Color] = [.accentGreen, .accentBlue, .accentYellow, .accentPurple, .accentRed, .white]
                for i in 0..<80 {
                    let seed = Double(i) * 47.3
                    let x = (sin(seed + time * 0.4) * 0.5 + 0.5) * size.width
                    let yBase = (time * 120 + seed * 11.7).truncatingRemainder(dividingBy: size.height + 20)
                    let y = yBase - 20
                    let color = colors[i % colors.count]
                    let size = CGFloat.random(in: 5...10)
                    let rect = CGRect(x: x - size/2, y: y, width: size, height: size * 0.6)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.85)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
