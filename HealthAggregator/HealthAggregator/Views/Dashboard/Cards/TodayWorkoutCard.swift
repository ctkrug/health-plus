import SwiftUI

struct TodayWorkoutCard: View {
    let store: WorkoutStore
    @State private var showWorkoutList = false

    private var lastSession: WorkoutSession? {
        store.sessions.first
    }

    private var isToday: Bool {
        guard let s = lastSession else { return false }
        return Calendar.current.isDateInToday(s.startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(isToday ? "Today's Workout" : "Last Workout", systemImage: "dumbbell.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            if let session = lastSession {
                LastWorkoutSummary(session: session)
            } else {
                Text("No workouts yet. Start your first session!")
                    .font(.metricLabel(14))
                    .foregroundStyle(Color.textSecondary)
            }

            Button {
                showWorkoutList = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Start Workout")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentBlue)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .card()
        .sheet(isPresented: $showWorkoutList) {
            WorkoutListView()
        }
    }
}

struct LastWorkoutSummary: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(session.startDate.formatted(.relative(presentation: .named)))
                    .font(.metricLabel(12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(session.duration / 60))m")
                    .font(.metric(18))
                    .foregroundStyle(Color.accentBlue)
                Text("duration")
                    .font(.metricLabel(11))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(12)
        .background(Color.cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
