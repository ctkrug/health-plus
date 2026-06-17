import SwiftUI

// MARK: - Colors
extension Color {
    static let appBackground    = Color(hex: "#0A0A0F")
    static let cardBackground   = Color(hex: "#141420")
    static let cardBorder       = Color(hex: "#1E1E2E")
    static let accentBlue       = Color(hex: "#4A9EFF")
    static let accentGreen      = Color(hex: "#30D158")
    static let accentYellow     = Color(hex: "#FFD60A")
    static let accentRed        = Color(hex: "#FF453A")
    static let accentPurple     = Color(hex: "#BF5AF2")
    static let accentOrange     = Color(hex: "#FF9F0A")
    static let textPrimary      = Color.white
    static let textSecondary    = Color(hex: "#8E8E9E")
    static let textTertiary     = Color(hex: "#48485A")
    static let separatorColor   = Color(hex: "#1C1C2A")

    static func recoveryColor(for value: Double) -> Color {
        switch value {
        case 67...: return .accentGreen
        case 34..<67: return .accentYellow
        default: return .accentRed
        }
    }

    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography
extension Font {
    static func metric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func metricLabel(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func workoutUI(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

// MARK: - Card Modifier
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Shimmer loading
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: Color.white.opacity(0.06), location: phase),
                        .init(color: .clear, location: phase + 0.3),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
            )
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Ring View
struct RingView: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 10
    var diameter: CGFloat = 60

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Metric Row
struct MetricRow: View {
    let label: String
    let value: String
    let unit: String
    var color: Color = .textPrimary
    var delta: String? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.metricLabel(13))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                if let delta {
                    Text(delta)
                        .font(.metricLabel(11))
                        .foregroundStyle(delta.hasPrefix("-") ? Color.accentRed : Color.accentGreen)
                }
                Text(value)
                    .font(.metric(16))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.metricLabel(11))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if let action, let onAction {
                Button(action, action: onAction)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentBlue)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Sparkline
struct SparklineView: View {
    let values: [Double]
    var color: Color = .accentBlue
    var height: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            let maxV = values.max() ?? 1
            let minV = values.min() ?? 0
            let range = maxV - minV == 0 ? 1 : maxV - minV
            let pts = values.enumerated().map { i, v in
                CGPoint(
                    x: geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1)),
                    y: geo.size.height * (1 - CGFloat((v - minV) / range))
                )
            }
            if pts.count > 1 {
                Path { path in
                    path.move(to: pts[0])
                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
    }
}
