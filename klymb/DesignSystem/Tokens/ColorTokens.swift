//
//  ColorTokens.swift
//  klymb
//
//  Design System Color Tokens — Matte Charcoal, Architectural Grey & Velvet Terracotta.
//  Calibrated for OLED eye-comfort (~64% accent saturation, zero blue-black halation).
//

import SwiftUI

public extension Color {
    // MARK: - Hex Initializer
    init(hex: String, opacity: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: opacity
        )
    }

    // Helper for dynamic dark/light colors
    private static func dynamicColor(lightHex: String, darkHex: String) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .light
                ? UIColor(Color(hex: lightHex))
                : UIColor(Color(hex: darkHex))
        })
    }

    private static func dynamicColor(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .light
                ? UIColor(light)
                : UIColor(dark)
        })
    }

    // MARK: - Core Palette (Matte Charcoal & Warm Architectural Grey)
    enum KlymbBackground {
        public static let primary = Color.dynamicColor(lightHex: "F6F5F3", darkHex: "111113")
        public static let secondary = Color.dynamicColor(lightHex: "FFFFFF", darkHex: "18181B")
        public static let tertiary = Color.dynamicColor(lightHex: "ECEAE6", darkHex: "212125")
        public static let elevated = Color.dynamicColor(lightHex: "FFFFFF", darkHex: "26262B")
    }

    enum KlymbText {
        public static let primary = Color.dynamicColor(lightHex: "141316", darkHex: "F3F2EF")
        public static let secondary = Color.dynamicColor(lightHex: "66646B", darkHex: "94939B")
        public static let tertiary = Color.dynamicColor(lightHex: "99979E", darkHex: "5E5D64")
        public static let inverse = Color.dynamicColor(lightHex: "FFFFFF", darkHex: "111113")
    }

    enum KlymbBorder {
        public static let `default` = Color.dynamicColor(
            light: Color(hex: "141316", opacity: 0.09),
            dark: Color.white.opacity(0.08)
        )
        public static let subtle = Color.dynamicColor(
            light: Color(hex: "141316", opacity: 0.06),
            dark: Color.white.opacity(0.055)
        )
        public static let specularTop = Color.dynamicColor(
            light: Color.white.opacity(0.90),
            dark: Color.white.opacity(0.11)
        )
        public static let specularBottom = Color.dynamicColor(
            light: Color(hex: "141316", opacity: 0.06),
            dark: Color.white.opacity(0.025)
        )
    }

    // MARK: - Accents (Low-Glare Velvet Terracotta & Soft Copper)
    enum KlymbAccent {
        /// Velvet Terracotta (~64% saturation): active progress, streaks, focus cues
        public static let primary = Color.dynamicColor(lightHex: "D95326", darkHex: "D9683E")
        /// Warm Soft Copper for highlights, ranks 4-10, subtle telemetry emphasis
        public static let soft = Color.dynamicColor(lightHex: "E3683B", darkHex: "E38D64")
        /// Muted Terracotta tint for pills, selected surfaces, subtle glow
        public static let primaryMuted = Color.dynamicColor(
            light: Color(hex: "D95326", opacity: 0.12),
            dark: Color(hex: "D9683E", opacity: 0.14)
        )
        /// Secondary accent harmonized with warm copper family
        public static let secondary = Color.dynamicColor(lightHex: "B84A24", darkHex: "E38D64")
        /// Calm high-contrast Bone White CTA fill in Dark Mode / Deep Charcoal in Light Mode
        public static let boneCTA = Color.dynamicColor(lightHex: "141316", darkHex: "F2F1EE")
        /// Disabled CTA fill with legible ink contrast
        public static let disabledSurface = Color.dynamicColor(lightHex: "E3E1DC", darkHex: "202024")
        public static let disabledText = Color.dynamicColor(lightHex: "9A989E", darkHex: "65646B")
    }

    // MARK: - Semantic Colors
    enum KlymbSemantic {
        /// Calm Mint exclusively for 100% completed goals, verified status, upward rank delta
        public static let success = Color.dynamicColor(lightHex: "129E5E", darkHex: "45C486")
        /// Warm Sandstone Amber for caution / cooldowns / rewards
        public static let warning = Color.dynamicColor(lightHex: "D9822B", darkHex: "E09850")
        /// Muted Coral Crimson for errors / downward delta / destructive actions
        public static let error = Color.dynamicColor(lightHex: "DC2626", darkHex: "E5586A")
        /// Cool Slate for informational state
        public static let info = Color.dynamicColor(lightHex: "475569", darkHex: "8E99A8")
    }

    // MARK: - Leaderboard Tier Colors
    enum KlymbRank {
        public static let gold = Color.dynamicColor(lightHex: "C9971E", darkHex: "E6B84C")
        public static let silver = Color.dynamicColor(lightHex: "7E828C", darkHex: "B8B8C2")
        public static let bronze = Color.dynamicColor(lightHex: "A66942", darkHex: "C4845C")
        public static let elite = Color.KlymbAccent.soft
    }
}

// MARK: - Gradients
public enum KlymbGradient {
    /// Active effort gradient (Velvet Terracotta → Soft Copper)
    public static let accent = LinearGradient(
        colors: [Color.KlymbAccent.primary, Color.KlymbAccent.soft],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Streak & peak effort gradient
    public static let fire = LinearGradient(
        colors: [Color.KlymbAccent.primary, Color(hex: "E59D68")],
        startPoint: .bottom,
        endPoint: .top
    )

    /// Subtle elevated charcoal surface sheen
    public static let card = LinearGradient(
        colors: [Color.KlymbBackground.tertiary, Color.KlymbBackground.secondary],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Rank 1 warmth gradient
    public static let rank = LinearGradient(
        colors: [Color.KlymbRank.gold, Color.KlymbAccent.primary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Directional top-edge hairline lighting gradient for borders
    public static let specularBorder = LinearGradient(
        colors: [Color.KlymbBorder.specularTop, Color.KlymbBorder.specularBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Direct Token Aliases (Backwards-compatible across existing views/models)
public enum ColorTokens {
    public static let backgroundPrimary = Color.KlymbBackground.primary
    public static let backgroundSecondary = Color.KlymbBackground.secondary
    public static let backgroundTertiary = Color.KlymbBackground.tertiary
    public static let surfaceElevated = Color.KlymbBackground.elevated
    public static let textPrimary = Color.KlymbText.primary
    public static let textSecondary = Color.KlymbText.secondary
    public static let textTertiary = Color.KlymbText.tertiary
    public static let textInverse = Color.KlymbText.inverse
    public static let borderDefault = Color.KlymbBorder.default
    public static let borderSubtle = Color.KlymbBorder.subtle

    // Cohesive Terracotta/Copper Palette Aliases
    public static let terracotta = Color.KlymbAccent.primary
    public static let softCopper = Color.KlymbAccent.soft
    public static let boneCTA = Color.KlymbAccent.boneCTA

    // Legacy token names preserved and mapped cleanly to the new palette
    public static let electricCyan = Color.KlymbAccent.primary
    public static let neonPurple = Color.KlymbAccent.soft
    public static let neonGreen = Color.KlymbSemantic.success
    public static let neonYellow = Color.KlymbSemantic.warning
    public static let neonOrange = Color.KlymbAccent.primary
    public static let neonRed = Color.KlymbSemantic.error
}
