import SwiftUI

struct NutritionCard: View {
    let hk: HealthKitService

    private var calProgress: Double { min(hk.caloriesConsumed / max(hk.calorieGoal, 1), 1.0) }
    private var totalMacros: Double { hk.proteinGrams + hk.carbGrams + hk.fatGrams }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Nutrition", systemImage: "fork.knife.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            // Calorie bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(Int(hk.caloriesConsumed))")
                            .font(.metric(24))
                            .foregroundStyle(Color.textPrimary)
                        Text("/ \(Int(hk.calorieGoal)) kcal")
                            .font(.metricLabel(13))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text("\(Int((hk.calorieGoal - hk.caloriesConsumed).magnitude)) remaining")
                        .font(.metricLabel(12))
                        .foregroundStyle(hk.caloriesConsumed > hk.calorieGoal ? Color.accentRed : Color.accentGreen)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.cardBorder)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(hk.caloriesConsumed > hk.calorieGoal ? Color.accentRed : Color.accentGreen)
                            .frame(width: geo.size.width * calProgress)
                            .animation(.spring(response: 0.6), value: calProgress)
                    }
                }
                .frame(height: 8)
            }

            // Macro donut + bars
            HStack(alignment: .center, spacing: 20) {
                MacroDonut(protein: hk.proteinGrams, carbs: hk.carbGrams, fat: hk.fatGrams)
                    .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 8) {
                    MacroBar(label: "Protein", grams: hk.proteinGrams, total: totalMacros, color: .accentBlue)
                    MacroBar(label: "Carbs", grams: hk.carbGrams, total: totalMacros, color: .accentYellow)
                    MacroBar(label: "Fat", grams: hk.fatGrams, total: totalMacros, color: .accentOrange)
                }
                Spacer()
            }

            // No data banner
            if hk.caloriesConsumed == 0 {
                SetupBanner(
                    icon: "fork.knife",
                    message: "Connect MyFitnessPal → Health to see nutrition",
                    color: .accentGreen
                )
            }
        }
        .card()
    }
}

struct MacroDonut: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    private var total: Double { protein + carbs + fat }

    var body: some View {
        ZStack {
            if total > 0 {
                Circle()
                    .trim(from: 0, to: protein / total)
                    .stroke(Color.accentBlue, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: protein / total, to: (protein + carbs) / total)
                    .stroke(Color.accentYellow, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: (protein + carbs) / total, to: 1.0)
                    .stroke(Color.accentOrange, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            } else {
                Circle().stroke(Color.cardBorder, lineWidth: 10)
            }
        }
        .animation(.spring(response: 0.6), value: total)
    }
}

struct MacroBar: View {
    let label: String
    let grams: Double
    let total: Double
    let color: Color

    private var fraction: Double { total > 0 ? grams / total : 0 }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.metricLabel(12))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 50, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.cardBorder)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(response: 0.6), value: fraction)
                }
            }
            .frame(height: 6)
            Text("\(Int(grams))g")
                .font(.metricLabel(11))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

struct SetupBanner: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
