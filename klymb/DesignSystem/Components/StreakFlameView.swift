//
//  StreakFlameView.swift
//  klymb
//
//  Streak flame badge matching docs/DESIGN_SYSTEM.md §6.2 & §9.
//  Gentle flicker animation with accessibility Reduce Motion support.
//

import SwiftUI

public struct StreakFlameView: View {
    public let streakDays: Int
    public let isAtRisk: Bool

    public init(streakDays: Int, isAtRisk: Bool = false) {
        self.streakDays = streakDays
        self.isAtRisk = isAtRisk
    }

    public var body: some View {
        HStack(spacing: KlymbSpacing.xs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isAtRisk ? AnyShapeStyle(Color.KlymbSemantic.warning) : AnyShapeStyle(KlymbGradient.fire))
                .frame(width: 20, height: 22)
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    isActive: !UIAccessibility.isReduceMotionEnabled
                )

            Text("\(streakDays)")
                .font(Font.Klymb.headline)
                .foregroundStyle(Color.KlymbText.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, KlymbSpacing.md)
        .padding(.vertical, KlymbSpacing.xs)
        .background(
            Capsule()
                .fill(Color(hex: "FF6B00").opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(isAtRisk ? Color.KlymbSemantic.warning : Color(hex: "FF6B00").opacity(0.4), lineWidth: 1)
        )
        .fixedSize()
        .accessibilityLabel("\(streakDays) day streak")
    }
}

#Preview {
    HStack(spacing: 16) {
        StreakFlameView(streakDays: 7)
        StreakFlameView(streakDays: 21, isAtRisk: true)
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
