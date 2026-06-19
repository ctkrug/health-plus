import SwiftUI

// Reusable UI for the personalized insights engine (see Services/InsightsEngine.swift).

struct RatingBadge: View {
    let rating: MetricRating
    var body: some View {
        Text(rating.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(rating.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(rating.color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct InsightRow: View {
    let insight: MetricInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(insight.rating.color)
                .frame(width: 34, height: 34)
                .background(insight.rating.color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(insight.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    RatingBadge(rating: insight.rating)
                }
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(insight.value)
                        .font(.metric(17))
                        .foregroundStyle(Color.textPrimary)
                    if let target = insight.target {
                        Text(target)
                            .font(.metricLabel(11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                Text(insight.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct InsightsCard: View {
    let title: String
    let insights: [MetricInsight]
    var footer: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentPurple)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                InsightRow(insight: insight)
                if idx < insights.count - 1 {
                    Divider().overlay(Color.separatorColor)
                }
            }

            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.top, 2)
            }
        }
        .card()
    }
}

struct RecoveryGuidanceCard: View {
    let guidance: RecoveryGuidance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: guidance.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(guidance.rating.color)
                Text(guidance.headline)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                RatingBadge(rating: guidance.rating)
            }

            Text(guidance.recommendation)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(guidance.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentYellow)
                        .padding(.top, 2)
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(guidance.rating.color.opacity(0.4), lineWidth: 1)
        )
    }
}
