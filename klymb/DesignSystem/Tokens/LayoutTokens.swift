//
//  LayoutTokens.swift
//  klymb
//
//  Spacing, corner radii, and specular surface modifiers.
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

    /// 12pt: Input fields, segmented tabs
    public static let md: CGFloat = 12

    /// 16pt: Standard surfaces, buttons
    public static let lg: CGFloat = 16

    /// 22pt: Hero cards, console modules, sheets
    public static let xl: CGFloat = 22

    /// 9999pt: Circular elements
    public static let full: CGFloat = 9999
}

// MARK: - Architectural Surface Modifier (Top-lit hairline specular border, zero harsh glare)
public struct KlymbCardStyle: ViewModifier {
    public var cornerRadius: CGFloat
    public var isHighlighted: Bool
    public var accentColor: Color
    public var isElevated: Bool

    public init(
        cornerRadius: CGFloat = KlymbRadius.lg,
        isHighlighted: Bool = false,
        accentColor: Color = Color.KlymbAccent.primary,
        isElevated: Bool = false
    ) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.accentColor = accentColor
        self.isElevated = isElevated
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(
                Group {
                    if isElevated {
                        KlymbGradient.card
                    } else {
                        Color.KlymbBackground.secondary
                    }
                }
            )
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    isHighlighted
                        ? AnyShapeStyle(accentColor.opacity(0.45))
                        : AnyShapeStyle(KlymbGradient.specularBorder),
                    lineWidth: isHighlighted ? 1.25 : 1.0
                )
            )
    }
}

public extension View {
    func klymbCardStyle(
        cornerRadius: CGFloat = KlymbRadius.lg,
        isHighlighted: Bool = false,
        accentColor: Color = Color.KlymbAccent.primary,
        isElevated: Bool = false
    ) -> some View {
        self.modifier(
            KlymbCardStyle(
                cornerRadius: cornerRadius,
                isHighlighted: isHighlighted,
                accentColor: accentColor,
                isElevated: isElevated
            )
        )
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
