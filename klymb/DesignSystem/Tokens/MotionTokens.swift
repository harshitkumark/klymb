//
//  MotionTokens.swift
//  klymb
//
//  Animation curves, durations, and accessibility Reduce Motion tokens.
//  Follows AGENTS.md Rule 18.
//

import SwiftUI

public enum MotionTokens {
    // MARK: - Durations
    public static let durationInstant: Double = 0.1
    public static let durationFast: Double = 0.2
    public static let durationStandard: Double = 0.35
    public static let durationRelaxed: Double = 0.6

    // MARK: - Standard Curves
    public static let springBouncy = Animation.spring(response: 0.35, dampingFraction: 0.68)
    public static let springStandard = Animation.spring(response: 0.32, dampingFraction: 0.82)
    public static let springSnappy = Animation.spring(response: 0.22, dampingFraction: 0.86)
    public static let easeOutSmooth = Animation.easeOut(duration: 0.4)
    public static let easeInOutStandard = Animation.easeInOut(duration: 0.3)

    // MARK: - Accessible Animation Resolution
    public static func resolve(
        _ animation: Animation,
        reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled
    ) -> Animation? {
        reduceMotion ? nil : animation
    }
}

// MARK: - View Extension for Reduce Motion
public extension View {
    /// Applies animation only if Reduce Motion is disabled by the user
    func accessibleAnimation<V: Equatable>(
        _ animation: Animation = MotionTokens.springStandard,
        value: V
    ) -> some View {
        self.animation(UIAccessibility.isReduceMotionEnabled ? nil : animation, value: value)
    }

    /// Scale effect that automatically collapses to 1.0 if Reduce Motion is active
    func accessibleScale(
        _ scale: CGFloat,
        anchor: UnitPoint = .center
    ) -> some View {
        self.scaleEffect(UIAccessibility.isReduceMotionEnabled ? 1.0 : scale, anchor: anchor)
    }
}
