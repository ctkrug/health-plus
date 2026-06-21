import SwiftUI

// MARK: - Theme system
//
// A selectable visual theme drives every semantic color token in `DesignSystem.swift`.
// Each theme is a hand-tuned palette (surfaces + text + six accents + a signature brand gradient).
// The active theme is stored in UserDefaults under "appTheme"; `Color.appBackground` & friends read
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

    let brandStart: Color        // signature gradient — brand mark, primary buttons, avatar
    let brandEnd: Color

    let shadowOpacity: Double     // card elevation strength (higher for light themes)

    init(bg: String, card: String, elevated: String, border: String, sep: String,
         t1: String, t2: String, t3: String,
         blue: String, green: String, yellow: String, red: String, purple: String, orange: String,
         brandA: String, brandB: String, shadow: Double) {
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
        brandStart = Color(hex: brandA)
        brandEnd = Color(hex: brandB)
        shadowOpacity = shadow
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case midnight      // refined deep navy → indigo (default)
    case obsidian      // true-black OLED, electric blue → violet
    case aurora        // vivid indigo night, purple → pink
    case forest        // deep green, emerald → teal
    case sunset        // warm charcoal, coral → amber
    case mocha         // cozy warm brown, caramel → gold
    case daylight      // clean light, blue → violet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "Midnight"
        case .obsidian: return "Obsidian"
        case .aurora:   return "Aurora"
        case .forest:   return "Forest"
        case .sunset:   return "Sunset"
        case .mocha:    return "Mocha"
        case .daylight: return "Daylight"
        }
    }

    var blurb: String {
        switch self {
        case .midnight: return "Deep navy · calm"
        case .obsidian: return "True black · electric"
        case .aurora:   return "Neon night · vivid"
        case .forest:   return "Emerald · earthy"
        case .sunset:   return "Coral glow · warm"
        case .mocha:    return "Caramel · cozy"
        case .daylight: return "Bright · clean"
        }
    }

    var scheme: ColorScheme { self == .daylight ? .light : .dark }

    var palette: ThemePalette {
        switch self {
        case .midnight: return Self.midnightPalette
        case .obsidian: return Self.obsidianPalette
        case .aurora:   return Self.auroraPalette
        case .forest:   return Self.forestPalette
        case .sunset:   return Self.sunsetPalette
        case .mocha:    return Self.mochaPalette
        case .daylight: return Self.daylightPalette
        }
    }

    /// Active theme, read from UserDefaults (source of truth shared with `@AppStorage("appTheme")`).
    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .midnight
    }

    // MARK: - Palettes (cached)

    private static let midnightPalette = ThemePalette(
        bg: "#0E1016", card: "#181B23", elevated: "#1F2330", border: "#282D3A", sep: "#20242E",
        t1: "#ECEEF3", t2: "#9AA1B0", t3: "#5C6373",
        blue: "#6E9BE0", green: "#5FCB94", yellow: "#E8C56A", red: "#E78A86", purple: "#A78BE6", orange: "#E6A463",
        brandA: "#6E9BE0", brandB: "#9B7BE6", shadow: 0.24)

    private static let obsidianPalette = ThemePalette(
        bg: "#000000", card: "#0E0E12", elevated: "#18181F", border: "#232329", sep: "#161619",
        t1: "#F6F6F9", t2: "#9F9FAA", t3: "#56565F",
        blue: "#4F8CFF", green: "#2EE6A6", yellow: "#FFC53D", red: "#FF6B81", purple: "#B58CFF", orange: "#FF9A4D",
        brandA: "#4F8CFF", brandB: "#7B5CFF", shadow: 0.40)

    private static let auroraPalette = ThemePalette(
        bg: "#0C0A18", card: "#16132A", elevated: "#1F1B3A", border: "#2A2548", sep: "#1B1733",
        t1: "#EDEAFB", t2: "#A6A0C8", t3: "#635D85",
        blue: "#6FA8FF", green: "#4FE0C0", yellow: "#F4D06A", red: "#FF6F9A", purple: "#B07CFF", orange: "#FF9A6A",
        brandA: "#A06CFF", brandB: "#FF6FB5", shadow: 0.32)

    private static let forestPalette = ThemePalette(
        bg: "#0B130E", card: "#13201A", elevated: "#1B2C23", border: "#25372C", sep: "#19271F",
        t1: "#E9F1EB", t2: "#9EB2A6", t3: "#5F7468",
        blue: "#54BBCB", green: "#5FCB8C", yellow: "#DCB75F", red: "#E0938A", purple: "#A795D4", orange: "#DCA05E",
        brandA: "#5FCB8C", brandB: "#54BBCB", shadow: 0.27)

    private static let sunsetPalette = ThemePalette(
        bg: "#15100C", card: "#221A14", elevated: "#2C2118", border: "#36291F", sep: "#271E17",
        t1: "#F5ECE3", t2: "#B6A493", t3: "#75665A",
        blue: "#ED8E6B", green: "#8FC785", yellow: "#F0C75F", red: "#E5746A", purple: "#CE8FB0", orange: "#E8A659",
        brandA: "#ED8E6B", brandB: "#F0C75F", shadow: 0.30)

    private static let mochaPalette = ThemePalette(
        bg: "#150F0A", card: "#211913", elevated: "#2C2118", border: "#38291E", sep: "#271D15",
        t1: "#F3E9DD", t2: "#B7A491", t3: "#786757",
        blue: "#C98F5A", green: "#9DBE7A", yellow: "#E2B85E", red: "#D8836B", purple: "#BE8FA0", orange: "#D99B5C",
        brandA: "#D9A05B", brandB: "#C97B54", shadow: 0.30)

    private static let daylightPalette = ThemePalette(
        bg: "#F5F6FA", card: "#FFFFFF", elevated: "#EDF0F6", border: "#E3E7EE", sep: "#E8EBF1",
        t1: "#1A1D24", t2: "#5C6470", t3: "#99A0AB",
        blue: "#3A69B5", green: "#2C9056", yellow: "#B5872F", red: "#C5524C", purple: "#7A5FBE", orange: "#C2772F",
        brandA: "#3A69B5", brandB: "#6E5FC0", shadow: 0.08)
}

// MARK: - Theme preview card (used in the picker)

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    private var p: ThemePalette { theme.palette }
    private var brand: LinearGradient {
        LinearGradient(colors: [p.brandStart, p.brandEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

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
                        Capsule().fill(brand).frame(width: 56, height: 11)
                    }
                    .padding(10)
                }
                .frame(height: 96)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? AnyShapeStyle(brand) : AnyShapeStyle(p.cardBorder), lineWidth: isSelected ? 2 : 0.5)
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
                            .foregroundStyle(brand)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
