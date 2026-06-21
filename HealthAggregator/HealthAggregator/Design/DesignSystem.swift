import SwiftUI
import UIKit

// MARK: - Colors
//
// Every semantic token resolves from the active `AppTheme` (see Theme.swift). Tokens are computed
// `static var`s reading `AppTheme.current.palette`; switching theme rebuilds the view tree
// (the app root keys its identity on the theme) so all colors re-resolve. Pick from 5 hand-tuned
// palettes in Profile → Theme. Never hardcode hex in views — add/extend a palette instead.
extension Color {
    private static var p: ThemePalette { AppTheme.current.palette }

    // Surfaces
    static var appBackground: Color  { p.appBackground }
    static var cardBackground: Color { p.cardBackground }
    static var cardElevated: Color   { p.cardElevated }
    static var cardBorder: Color     { p.cardBorder }
    static var separatorColor: Color { p.separator }

    // Soft elevation shadow tuned per theme (strong in light, subtle in dark)
    static var cardShadow: Color     { Color.black.opacity(p.shadowOpacity) }

    // Text
    static var textPrimary: Color    { p.textPrimary }
    static var textSecondary: Color  { p.textSecondary }
    static var textTertiary: Color   { p.textTertiary }

    // Accents
    static var accentBlue: Color     { p.accentBlue }
    static var accentGreen: Color    { p.accentGreen }
    static var accentYellow: Color   { p.accentYellow }
    static var accentRed: Color      { p.accentRed }
    static var accentPurple: Color   { p.accentPurple }
    static var accentOrange: Color   { p.accentOrange }

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
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cardBackground)
                    .shadow(color: Color.cardShadow, radius: 12, x: 0, y: 5)
            )
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
            .padding(.top, 4)
            .padding(.bottom, subtitle != nil ? 4 : 12)

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

// MARK: - Floating action button style
// Primary actions live bottom-trailing (never in the top-right corner of the app).
extension View {
    /// Style an icon as a circular floating button.
    func fabStyle(primary: Bool = true, diameter: CGFloat = 56) -> some View {
        self
            .font(.system(size: primary ? 22 : 18, weight: .semibold))
            .foregroundStyle(primary ? Color.white : Color.textSecondary)
            .frame(width: diameter, height: diameter)
            .background(primary ? Color.accentBlue : Color.cardBackground)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(primary ? Color.clear : Color.cardBorder, lineWidth: 0.5))
            .shadow(color: primary ? Color.accentBlue.opacity(0.35) : Color.cardShadow, radius: 8, y: 3)
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
