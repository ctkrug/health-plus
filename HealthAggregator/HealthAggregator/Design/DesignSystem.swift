import SwiftUI
import UIKit

// MARK: - Colors
//
// Soothing, accessible palette that adapts to light & dark mode automatically. Every semantic token
// is an adaptive color (a UIColor dynamic provider) that resolves to a calm, desaturated tone in
// each appearance. Accents are intentionally muted — no neon — for an easy-on-the-eyes feel.
extension Color {
    // Surfaces
    static let appBackground    = Color(light: "#F4F6FA", dark: "#0F1115")
    static let cardBackground   = Color(light: "#FFFFFF", dark: "#181B22")
    static let cardBorder       = Color(light: "#E5E8EE", dark: "#272B33")
    static let separatorColor   = Color(light: "#E9ECF1", dark: "#20242B")

    // Text
    static let textPrimary      = Color(light: "#1B1E24", dark: "#ECEEF1")
    static let textSecondary    = Color(light: "#5E6470", dark: "#9AA1AC")
    static let textTertiary     = Color(light: "#9AA0AB", dark: "#5B616C")

    // Accents (muted — deeper in light mode for contrast, softer in dark)
    static let accentBlue       = Color(light: "#3C6CB4", dark: "#6E9BD8")
    static let accentGreen      = Color(light: "#2F8F57", dark: "#6FC58C")
    static let accentYellow     = Color(light: "#B8893A", dark: "#E6C46E")
    static let accentRed        = Color(light: "#C2554F", dark: "#E08B86")
    static let accentPurple     = Color(light: "#7E63B8", dark: "#A98FD8")
    static let accentOrange     = Color(light: "#C57A38", dark: "#E0A36A")

    static func recoveryColor(for value: Double) -> Color {
        switch value {
        case 67...: return .accentGreen
        case 34..<67: return .accentYellow
        default: return .accentRed
        }
    }

    /// Adaptive color from two hex strings — resolves per the active light/dark appearance.
    init(light: String, dark: String) {
        self = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
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

extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
            blue: CGFloat(rgb & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Appearance setting
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
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

// MARK: - App Header
struct AppHeader<Trailing: View>: View {
    var subtitle: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.accentBlue)
                    Text("HealthSync")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .tracking(0.3)
                }
                Spacer()
                trailing()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, subtitle != nil ? 4 : 14)

            if let subtitle {
                HStack {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            Rectangle()
                .fill(Color.separatorColor)
                .frame(height: 0.5)
        }
        .background(Color.cardBackground.ignoresSafeArea(edges: .top))
    }
}

extension AppHeader where Trailing == EmptyView {
    init(subtitle: String? = nil) {
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
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
