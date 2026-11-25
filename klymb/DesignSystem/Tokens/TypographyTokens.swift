//
//  TypographyTokens.swift
//  klymb
//
//  Typography system pairing tight SF Pro Display titles,
//  Condensed athletic numerals, and Monospaced telemetry labels.
//  Preserves Dynamic Type across all text styles (AGENTS.md Rule 18).
//

import SwiftUI

public extension Font {
    enum Klymb {
        /// Hero KP display counter — condensed athletic presence + tabular alignment
        public static let titleHero = Font.system(.largeTitle, design: .default, weight: .heavy)
            .width(.condensed)

        /// Primary screen titles
        public static let titleLarge = Font.system(.largeTitle, design: .default, weight: .bold)

        /// Section / major headers
        public static let titleMedium = Font.system(.title, design: .default, weight: .bold)

        /// Card & sheet headers
        public static let titleSmall = Font.system(.title2, design: .default, weight: .semibold)

        /// List row titles & primary CTAs
        public static let headline = Font.system(.headline, design: .default, weight: .semibold)

        /// Primary body copy
        public static let body = Font.system(.body, design: .default, weight: .regular)

        /// Secondary body / subheaders
        public static let bodySmall = Font.system(.subheadline, design: .default, weight: .regular)

        /// Metadata, eyebrows & labels
        public static let caption = Font.system(.caption, design: .default, weight: .medium)

        /// Footnotes & compact telemetry
        public static let captionSmall = Font.system(.caption2, design: .default, weight: .regular)

        // MARK: - Athletic & Telemetry Tokens
        /// Animated KP dial counter (condensed athletic width + monospaced digits)
        public static let kpCounter = Font.system(.largeTitle, design: .default, weight: .heavy)
            .width(.condensed)
            .monospacedDigit()

        /// Big athletic stat / Quick Log number
        public static let athleticMetric = Font.system(.title2, design: .default, weight: .heavy)
            .width(.condensed)
            .monospacedDigit()

        /// Inline KP numbers in tables & badges
        public static let kpInline = Font.system(.subheadline, design: .monospaced, weight: .bold)

        /// Leaderboard ranks
        public static let rankNumber = Font.system(.subheadline, design: .monospaced, weight: .bold)

        /// Monospaced telemetry eyebrow label
        public static let telemetry = Font.system(.caption2, design: .monospaced, weight: .semibold)
    }
}

// MARK: - Direct Typography Token Aliases
public enum TypographyTokens {
    public static let largeTitle = Font.Klymb.titleHero
    public static let title1 = Font.Klymb.titleLarge
    public static let title2 = Font.Klymb.titleMedium
    public static let titleSmall = Font.Klymb.titleSmall
    public static let headline = Font.Klymb.headline
    public static let body = Font.Klymb.body
    public static let subheadline = Font.Klymb.bodySmall
    public static let caption1 = Font.Klymb.caption
    public static let caption2 = Font.Klymb.captionSmall
    public static let telemetry = Font.Klymb.telemetry
    public static let kpInline = Font.Klymb.kpInline
    public static let athleticMetric = Font.Klymb.athleticMetric
}
