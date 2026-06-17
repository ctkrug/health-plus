import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setNumber: Int
        var totalSets: Int
        var restSeconds: Int?
        var isResting: Bool
        var elapsedSeconds: Int
    }

    var workoutName: String
}

// MARK: - Live Activity Manager

@Observable
final class LiveActivityManager {
    private var activity: Activity<WorkoutActivityAttributes>?

    func startActivity(workoutName: String, exerciseName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutActivityAttributes(workoutName: workoutName)
        let state = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            setNumber: 1, totalSets: 4,
            restSeconds: nil, isResting: false,
            elapsedSeconds: 0
        )

        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(exerciseName: String, setNumber: Int, totalSets: Int, restSeconds: Int?, isResting: Bool, elapsed: Int) {
        let state = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            setNumber: setNumber, totalSets: totalSets,
            restSeconds: restSeconds, isResting: isResting,
            elapsedSeconds: elapsed
        )
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        Task { await activity?.end(nil, dismissalPolicy: .immediate) }
        activity = nil
    }
}
