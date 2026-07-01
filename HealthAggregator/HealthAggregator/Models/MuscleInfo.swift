import Foundation
import MuscleMap

/// Hand-authored educational content per tracked muscle group. Not computed and not
/// science-threshold-grade (that rigor is reserved for `MuscleBalanceEngine`'s volume landmarks
/// and antagonist ratios, cited in docs/SCIENCE.md §11) — this is plain-English anatomy/kinesiology
/// context, kept light and non-diagnostic (not medical advice).
struct MuscleInfo {
    let group: Muscle
    let displayName: String
    let anatomicalName: String?
    let function: String
    let whyItMatters: String
    let synergists: [Muscle]
    let antagonist: Muscle?
    let notes: String?
}

enum MuscleLibrary {
    static let all: [Muscle: MuscleInfo] = Dictionary(uniqueKeysWithValues: entries.map { ($0.group, $0) })

    static func info(for muscle: Muscle) -> MuscleInfo {
        all[muscle] ?? MuscleInfo(
            group: muscle, displayName: muscle.displayName, anatomicalName: nil,
            function: "", whyItMatters: "", synergists: [], antagonist: nil, notes: nil)
    }

    private static let entries: [MuscleInfo] = [
        MuscleInfo(
            group: .chest, displayName: "Chest", anatomicalName: "Pectoralis Major",
            function: "Pulls the arm across and toward the body — the main mover in every pressing motion.",
            whyItMatters: "Upper-body pushing strength (pushing a door, a shopping cart, getting up off the floor) and a major driver of upper-body size.",
            synergists: [.triceps, .deltoids], antagonist: .upperBack,
            notes: "Chronic overtraining relative to the back is linked to rounded-shoulder posture."),

        MuscleInfo(
            group: .upperBack, displayName: "Back", anatomicalName: "Latissimus Dorsi / Rhomboids / Mid-Traps",
            function: "Pulls the arm down and back, and pulls the shoulder blades together — the main mover in every rowing and pulldown motion.",
            whyItMatters: "Postural counterbalance to all the pressing you do in daily life and training; a weak back relative to chest is the single most common upper-body imbalance.",
            synergists: [.biceps, .rearDeltoid], antagonist: .chest,
            notes: nil),

        MuscleInfo(
            group: .lowerBack, displayName: "Lower Back", anatomicalName: "Erector Spinae",
            function: "Extends and stabilizes the spine — resists forward bending under load.",
            whyItMatters: "Spinal stability for every lift and for daily bending/lifting; a common site of injury when it's undertrained relative to the muscles around it.",
            synergists: [.gluteal, .hamstring], antagonist: .abs,
            notes: "Directly relevant to back rehab — undertrained erectors relative to the anterior core is a common contributor to low-back pain."),

        MuscleInfo(
            group: .trapezius, displayName: "Traps", anatomicalName: "Trapezius",
            function: "Elevates, retracts, and rotates the shoulder blade — stabilizes the shoulder during overhead and pulling work.",
            whyItMatters: "Shoulder-girdle stability; a weak upper back and traps relative to the chest and delts is a common driver of shoulder discomfort.",
            synergists: [.rhomboids, .upperBack], antagonist: nil,
            notes: nil),

        MuscleInfo(
            group: .deltoids, displayName: "Shoulders", anatomicalName: "Deltoids",
            function: "Raises the arm in every direction — front fibers drive pressing, rear fibers drive pulling and posture.",
            whyItMatters: "Shoulder size and function; the rear-delt fibers in particular counterbalance chest-dominant training and support shoulder-joint health.",
            synergists: [.triceps, .rotatorCuff], antagonist: nil,
            notes: nil),

        MuscleInfo(
            group: .rotatorCuff, displayName: "Rotator Cuff", anatomicalName: "Supraspinatus / Infraspinatus / Teres Minor / Subscapularis",
            function: "A group of small muscles that hold the head of the humerus centered in the shoulder socket during every arm movement.",
            whyItMatters: "The shoulder's stabilizer — chronically undertrained relative to the big pressing muscles, which is a leading cause of shoulder impingement in lifters.",
            synergists: [.deltoids], antagonist: nil,
            notes: "Low volume by design — a little goes a long way (face pulls, external rotations)."),

        MuscleInfo(
            group: .biceps, displayName: "Biceps", anatomicalName: "Biceps Brachii",
            function: "Bends the elbow and rotates the forearm — the main mover in every curling motion, and a synergist in every pulling motion.",
            whyItMatters: "Everyday carrying/lifting strength and arm size; trains for free as a synergist on every back exercise, so dedicated volume is really about extra size.",
            synergists: [.upperBack], antagonist: .triceps,
            notes: nil),

        MuscleInfo(
            group: .triceps, displayName: "Triceps", anatomicalName: "Triceps Brachii",
            function: "Straightens the elbow — the main mover in every pressing and pushdown motion.",
            whyItMatters: "Makes up most of the upper arm's size, more than biceps; also trains for free as a synergist on every pressing exercise.",
            synergists: [.chest, .deltoids], antagonist: .biceps,
            notes: nil),

        MuscleInfo(
            group: .quadriceps, displayName: "Quads", anatomicalName: "Quadriceps Femoris",
            function: "Straightens the knee — the main mover in every squat, lunge, and leg-extension motion.",
            whyItMatters: "Everyday standing/walking/stair strength and one of the biggest muscle groups in the body; a common site of overuse when it's trained heavily without matching hamstring work.",
            synergists: [.gluteal], antagonist: .hamstring,
            notes: "Directly relevant to knee rehab — a strength imbalance favoring quads over hamstrings is a well-known knee-strain risk factor."),

        MuscleInfo(
            group: .hamstring, displayName: "Hamstrings", anatomicalName: "Biceps Femoris / Semitendinosus / Semimembranosus",
            function: "Bends the knee and extends the hip — the main mover in every deadlift, leg-curl, and hip-hinge motion.",
            whyItMatters: "Knee-joint stability (works opposite the quads to protect the knee) and hip-hinge strength for everyday lifting.",
            synergists: [.gluteal, .lowerBack], antagonist: .quadriceps,
            notes: "Directly relevant to knee rehab — see the Hamstrings : Quads balance check."),

        MuscleInfo(
            group: .gluteal, displayName: "Glutes", anatomicalName: "Gluteus Maximus",
            function: "Extends the hip — the main mover in every hip-thrust, squat, and deadlift lockout.",
            whyItMatters: "The body's largest and strongest muscle; drives hip power for lifting, running, and jumping, and supports lower-back health as part of the posterior chain.",
            synergists: [.hamstring], antagonist: nil,
            notes: nil),

        MuscleInfo(
            group: .adductors, displayName: "Inner Thighs", anatomicalName: "Adductor Group",
            function: "Pulls the leg toward the midline — stabilizes the hip and knee during single-leg and lateral movement.",
            whyItMatters: "Hip and knee stability during squats, lunges, and direction changes; often undertrained since few exercises target it directly.",
            synergists: [.hamstring], antagonist: nil,
            notes: nil),

        MuscleInfo(
            group: .calves, displayName: "Calves", anatomicalName: "Gastrocnemius / Soleus",
            function: "Points the foot down — the main mover in every calf raise, and a key contributor to running/jumping power.",
            whyItMatters: "Ankle stability and push-off power for walking, running, and every squat/lunge variation.",
            synergists: [], antagonist: nil,
            notes: nil),

        MuscleInfo(
            group: .abs, displayName: "Abs", anatomicalName: "Rectus Abdominis",
            function: "Flexes the spine forward and resists extension — the main stabilizer in every plank, crunch, and heavy compound lift.",
            whyItMatters: "Core stability that transfers to every other lift; works opposite the lower back to keep the spine balanced under load.",
            synergists: [.obliques], antagonist: .lowerBack,
            notes: "Directly relevant to back rehab — see the Posterior Chain : Anterior Core balance check."),

        MuscleInfo(
            group: .obliques, displayName: "Obliques", anatomicalName: "External / Internal Oblique",
            function: "Rotates and side-bends the spine — resists twisting forces during nearly every standing or loaded movement.",
            whyItMatters: "Rotational core strength and stability for everyday twisting movements (and most sports); complements straight-plane ab and back training.",
            synergists: [.abs], antagonist: nil,
            notes: nil),
    ]
}
