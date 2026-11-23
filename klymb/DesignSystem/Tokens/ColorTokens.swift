//
//  ColorTokens.swift
//  klymb
//
//  Design System Color Tokens matching docs/DESIGN_SYSTEM.md §2.
//  Dark mode first, supporting Dynamic Type and contrast accessibility.
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

    // MARK: - Core Palette
    enum KlymbBackground {
        public static let primary = Color.dynamicColor(lightHex: "FFFFFF", darkHex: "0A0A0F")
        public static let secondary = Color.dynamicColor(lightHex: "F5F5F7", darkHex: "141420")
        public static let tertiary = Color.dynamicColor(lightHex: "E8E8ED", darkHex: "1C1C2E")
        public static let elevated = Color.dynamicColor(lightHex: "FFFFFF", darkHex: "1E1E32")
    }

    enum KlymbText {
        public static let primary = Color.dynamicColor(lightHex: "1A1A1A", darkHex: "F0F0F5")
        public static let secondary = Color.dynamicColor(lightHex: "6B6B80", darkHex: "8E8EA0")
        public static let tertiary = Color.dynamicColor(lightHex: "9B9BAD", darkHex: "5C5C6E")
        public static let inverse = Color.dynamicColor(lightHex: "F0F0F5", darkHex: "0A0A0F")
    }

    enum KlymbBorder {
        public static let `default` = Color.dynamicColor(lightHex: "E0E0E8", darkHex: "2A2A3D")
        public static let subtle = Color.dynamicColor(lightHex: "F0F0F5", darkHex: "1E1E32")
    }

    // MARK: - Accents
    enum KlymbAccent {
        /// Electric Cyan: Primary actions, KP counter, Klymb brand signature
        public static let primary = Color(hex: "00E5FF")
        /// Electric Cyan at 20% opacity for selections & subtle glows
        public static let primaryMuted = Color(hex: "00E5FF", opacity: 0.20)
        /// Vivid Purple: Secondary highlights, challenges, teams
        public static let secondary = Color(hex: "7B61FF")
    }

    // MARK: - Semantic Colors
    enum KlymbSemantic {
        public static let success = Color(hex: "00D68F")
        public static let warning = Color(hex: "FFB800")
        public static let error = Color(hex: "FF3D71")
        public static let info = Color(hex: "00B4D8")
    }

    // MARK: - Leaderboard Tier Colors
    enum KlymbRank {
        public static let gold = Color(hex: "FFD700")
        public static let silver = Color(hex: "C0C0C0")
        public static let bronze = Color(hex: "CD7F32")
        public static let elite = Color(hex: "00E5FF")
    }
}

// MARK: - Gradients (DESIGN_SYSTEM.md §2.4)
public enum KlymbGradient {
    /// CTA buttons, KP counter glow, achievement unlock (Cyan → Purple, 45°)
    public static let accent = LinearGradient(
        colors: [Color.KlymbAccent.primary, Color.KlymbAccent.secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Streak flame, hot streaks (Orange → Amber, vertical)
    public static let fire = LinearGradient(
        colors: [Color(hex: "FF6B00"), Color(hex: "FFB800")],
        startPoint: .bottom,
        endPoint: .top
    )

    /// Card backgrounds with subtle depth
    public static let card = LinearGradient(
        colors: [Color(hex: "1E1E32"), Color(hex: "141420")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Rank celebration (Gold → Orange)
    public static let rank = LinearGradient(
        colors: [Color.KlymbRank.gold, Color(hex: "FF6B00")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
