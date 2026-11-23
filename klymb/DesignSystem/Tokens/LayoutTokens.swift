//
//  LayoutTokens.swift
//  klymb
//
//  Spacing, corner radius, and elevation tokens matching docs/DESIGN_SYSTEM.md §4.
//

import SwiftUI

public enum KlymbSpacing {
    /// 2pt: Micro gap between icon and text
    public static let xxs: CGFloat = 2

    /// 4pt: Tight inline spacing
    public static let xs: CGFloat = 4

    /// 8pt: Between related elements
    public static let sm: CGFloat = 8

    /// 12pt: Standard component padding
    public static let md: CGFloat = 12

    /// 16pt: Card padding, between sections
    public static let lg: CGFloat = 16

    /// 24pt: Between major sections
    public static let xl: CGFloat = 24

    /// 32pt: Screen-level vertical padding
    public static let xxl: CGFloat = 32

    /// 48pt: Hero breathing room
    public static let xxxl: CGFloat = 48
}

public enum KlymbRadius {
    /// 8pt: Small chips, tags, badges
    public static let sm: CGFloat = 8

    /// 12pt: Input fields, small cards
    public static let md: CGFloat = 12

    /// 16pt: Standard cards, buttons
    public static let lg: CGFloat = 16

    /// 24pt: Large cards, modal sheets
    public static let xl: CGFloat = 24

    /// 9999pt: Circular elements (avatars, rank badges)
    public static let full: CGFloat = 9999
}

// MARK: - Elevation & Border Modifiers (DESIGN_SYSTEM.md §4.3)
public struct KlymbCardStyle: ViewModifier {
    public var cornerRadius: CGFloat
    public var isHighlighted: Bool

    public init(cornerRadius: CGFloat = KlymbRadius.xl, isHighlighted: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
    }

    public func body(content: Content) -> some View {
        content
            .background(Color.KlymbBackground.secondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isHighlighted ? Color.KlymbAccent.primary : Color.KlymbBorder.default,
                        lineWidth: isHighlighted ? 1.5 : 1.0
                    )
            )
            .shadow(
                color: isHighlighted ? Color.KlymbAccent.primary.opacity(0.15) : Color.clear,
                radius: 8,
                x: 0,
                y: 0
            )
    }
}

public extension View {
    func klymbCardStyle(cornerRadius: CGFloat = KlymbRadius.xl, isHighlighted: Bool = false) -> some View {
        self.modifier(KlymbCardStyle(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}

// MARK: - Direct Layout Token Aliases
public enum LayoutTokens {
    public static let spacingXS: CGFloat = KlymbSpacing.xs
    public static let spacingS: CGFloat = KlymbSpacing.sm
    public static let spacingM: CGFloat = KlymbSpacing.md
    public static let spacingL: CGFloat = KlymbSpacing.lg
    public static let spacingXL: CGFloat = KlymbSpacing.xl
    public static let spacingXXL: CGFloat = KlymbSpacing.xxl

    public static let paddingS: CGFloat = KlymbSpacing.sm
    public static let paddingM: CGFloat = KlymbSpacing.md
    public static let paddingL: CGFloat = KlymbSpacing.lg

    public static let radiusS: CGFloat = KlymbRadius.sm
    public static let radiusM: CGFloat = KlymbRadius.md
    public static let radiusL: CGFloat = KlymbRadius.lg
    public static let radiusXL: CGFloat = KlymbRadius.xl

    public static let screenHorizontalPadding: CGFloat = KlymbSpacing.lg
}
