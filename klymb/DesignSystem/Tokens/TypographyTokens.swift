//
//  TypographyTokens.swift
//  klymb
//
//  Typography tokens matching docs/DESIGN_SYSTEM.md §3.
//  Uses Dynamic Type styles and monospaced digits for gaming alignment.
//

import SwiftUI

public extension Font {
    enum Klymb {
        /// Hero KP counter on Home screen (48pt Bold)
        public static let titleHero = Font.system(.largeTitle, design: .default, weight: .bold)

        /// Screen titles (34pt Bold)
        public static let titleLarge = Font.system(.largeTitle, design: .default, weight: .bold)

        /// Section headers (28pt Bold)
        public static let titleMedium = Font.system(.title, design: .default, weight: .bold)

        /// Card titles, modal headers (22pt Semibold)
        public static let titleSmall = Font.system(.title2, design: .default, weight: .semibold)

        /// List row titles, button labels (17pt Semibold)
        public static let headline = Font.system(.headline, design: .default, weight: .semibold)

        /// Primary body text (17pt Regular)
        public static let body = Font.system(.body, design: .default, weight: .regular)

        /// Secondary body text (15pt Regular)
        public static let bodySmall = Font.system(.subheadline, design: .default, weight: .regular)

        /// Metadata, timestamps, labels (13pt Medium)
        public static let caption = Font.system(.caption, design: .default, weight: .medium)

        /// Footnotes, fine print (11pt Regular)
        public static let captionSmall = Font.system(.caption2, design: .default, weight: .regular)

        // MARK: - Monospaced Gaming Tokens
        /// Animated rolling KP count-up (48pt Bold Monospaced)
        public static let kpCounter = Font.system(.largeTitle, design: .monospaced, weight: .bold)

        /// KP values in lists and cards (17pt Semibold Monospaced)
        public static let kpInline = Font.system(.body, design: .monospaced, weight: .semibold)

        /// Rank numbers in leaderboard (22pt Bold Monospaced)
        public static let rankNumber = Font.system(.title2, design: .monospaced, weight: .bold)
    }
}

// MARK: - Direct Typography Token Aliases
public enum TypographyTokens {
    public static let largeTitle = Font.Klymb.titleHero
    public static let title1 = Font.Klymb.titleLarge
    public static let title2 = Font.Klymb.titleMedium
    public static let headline = Font.Klymb.headline
    public static let body = Font.Klymb.body
    public static let subheadline = Font.Klymb.bodySmall
    public static let caption1 = Font.Klymb.caption
    public static let caption2 = Font.Klymb.captionSmall
}
