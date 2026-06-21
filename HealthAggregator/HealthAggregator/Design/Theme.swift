import SwiftUI

// MARK: - Theme system
//
// A selectable visual theme drives every semantic color token in `DesignSystem.swift`.
// Each theme is a full, hand-tuned palette (surfaces + text + six accents). The active theme
// is stored in `UserDefaults` under "appTheme"; `Color.appBackground` & friends read
// `AppTheme.current.palette`, and the app root keys its identity on the theme so a switch
// re-resolves the whole tree (see HealthAggregatorApp).

struct ThemePalette {
    let appBackground: Color
    let cardBackground: Color
    let cardElevated: Color      // a slightly raised surface (insets, fields)
    let cardBorder: Color
    let separator: Color

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    let accentBlue: Color        // primary / brand — tab tint, primary buttons
    let accentGreen: Color
    let accentYellow: Color
    let accentRed: Color
    let accentPurple: Color
    let accentOrange: Color

    let shadowOpacity: Double    // card elevation strength (higher for light themes)

    init(bg: String, card: String, elevated: String, border: String, sep: String,
         t1: String, t2: String, t3: String,
         blue: String, green: String, yellow: String, red: String, purple: String, orange: String,
         shadow: Double) {
        appBackground = Color(hex: bg)
        cardBackground = Color(hex: card)
        cardElevated = Color(hex: elevated)
        cardBorder = Color(hex: border)
        separator = Color(hex: sep)
        textPrimary = Color(hex: t1)
        textSecondary = Color(hex: t2)
        textTertiary = Color(hex: t3)
        accentBlue = Color(hex: blue)
        accentGreen = Color(hex: green)
        accentYellow = Color(hex: yellow)
        accentRed = Color(hex: red)
        accentPurple = Color(hex: purple)
        accentOrange = Color(hex: orange)
        shadowOpacity = shadow
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case midnight      // refined dark navy (default)
    case obsidian      // true-black OLED, electric blue
    case forest        // deep green, emerald + teal
    case sunset        // warm charcoal, coral + amber
    case daylight      // clean light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "Midnight"
        case .obsidian: return "Obsidian"
        case .forest:   return "Forest"
        case .sunset:   return "Sunset"
        case .daylight: return "Daylight"
        }
    }

    var blurb: String {
        switch self {
        case .midnight: return "Deep navy · calm"
        case .obsidian: return "True black · OLED"
        case .forest:   return "Emerald · earthy"
        case .sunset:   return "Warm · coral glow"
        case .daylight: return "Bright · clean"
        }
    }

    var scheme: ColorScheme { self == .daylight ? .light : .dark }

    var palette: ThemePalette {
        switch self {
        case .midnight: return Self.midnightPalette
        case .obsidian: return Self.obsidianPalette
        case .forest:   return Self.forestPalette
        case .sunset:   return Self.sunsetPalette
        case .daylight: return Self.daylightPalette
        }
    }

    /// Active theme, read from UserDefaults (source of truth shared with `@AppStorage("appTheme")`).
    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .midnight
    }

    // MARK: - Palettes (cached)

    private static let midnightPalette = ThemePalette(
        bg: "#0F1115", card: "#181B22", elevated: "#1F232B", border: "#272B33", sep: "#20242B",
        t1: "#ECEEF1", t2: "#9AA1AC", t3: "#5B616C",
        blue: "#6E9BD8", green: "#6FC58C", yellow: "#E6C46E", red: "#E08B86", purple: "#A98FD8", orange: "#E0A36A",
        shadow: 0.22)

    private static let obsidianPalette = ThemePalette(
        bg: "#000000", card: "#0E0E11", elevated: "#17171C", border: "#202026", sep: "#161619",
        t1: "#F5F5F7", t2: "#A0A0A8", t3: "#56565E",
        blue: "#4F8CFF", green: "#34D399", yellow: "#FBBF24", red: "#FB7185", purple: "#A78BFA", orange: "#FB923C",
        shadow: 0.35)

    private static let forestPalette = ThemePalette(
        bg: "#0C140F", card: "#14201A", elevated: "#1B2A22", border: "#243429", sep: "#1A271F",
        t1: "#E8F0EA", t2: "#9DB0A4", t3: "#5E7167",
        blue: "#57B5C4", green: "#5FBF85", yellow: "#D8B25E", red: "#DB8A82", purple: "#A38FCB", orange: "#D69A5C",
        shadow: 0.26)

    private static let sunsetPalette = ThemePalette(
        bg: "#14100E", card: "#201A16", elevated: "#2A211B", border: "#332822", sep: "#261E19",
        t1: "#F4ECE4", t2: "#B4A498", t3: "#74675C",
        blue: "#E8896B", green: "#86C28A", yellow: "#EAC15C", red: "#E0736B", purple: "#C58FB7", orange: "#E0A05A",
        shadow: 0.28)

    private static let daylightPalette = ThemePalette(
        bg: "#F4F6FA", card: "#FFFFFF", elevated: "#EEF1F6", border: "#E5E8EE", sep: "#E9ECF1",
        t1: "#1B1E24", t2: "#5E6470", t3: "#9AA0AB",
        blue: "#3C6CB4", green: "#2F8F57", yellow: "#B8893A", red: "#C2554F", purple: "#7E63B8", orange: "#C57A38",
        shadow: 0.07)
}

// MARK: - Theme preview card (used in the picker)

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    private var p: ThemePalette { theme.palette }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Mini mockup
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(p.appBackground)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(p.cardBackground)
                            .frame(height: 26)
                            .overlay(
                                HStack(spacing: 5) {
                                    Circle().fill(p.accentBlue).frame(width: 9, height: 9)
                                    Circle().fill(p.accentGreen).frame(width: 9, height: 9)
                                    Circle().fill(p.accentOrange).frame(width: 9, height: 9)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                            )
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 3).fill(p.textPrimary).frame(width: 38, height: 6)
                            RoundedRectangle(cornerRadius: 3).fill(p.textSecondary).frame(width: 22, height: 6)
                        }
                        Capsule().fill(p.accentBlue).frame(width: 54, height: 10)
                    }
                    .padding(10)
                }
                .frame(height: 96)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentBlue : p.cardBorder, lineWidth: isSelected ? 2 : 0.5)
                )

                // Label
                HStack(spacing: 5) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(theme.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(theme.blurb)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.accentBlue)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
