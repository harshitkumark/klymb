//
//  StreakFlameView.swift
//  klymb
//
//  Sleek muted-copper streak badge tuned for OLED eye comfort and Reduce Motion.
//

import SwiftUI

public struct StreakFlameView: View {
    public let streakDays: Int
    public let isAtRisk: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(streakDays: Int, isAtRisk: Bool = false) {
        self.streakDays = streakDays
        self.isAtRisk = isAtRisk
    }

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isAtRisk ? AnyShapeStyle(Color.KlymbSemantic.warning) : AnyShapeStyle(Color.KlymbAccent.primary))
                .frame(width: 16, height: 18)
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    isActive: !reduceMotion && streakDays > 0
                )

            Text("\(streakDays)")
                .font(Font.Klymb.rankNumber)
                .foregroundStyle(Color.KlymbText.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.KlymbAccent.primaryMuted)
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isAtRisk ? Color.KlymbSemantic.warning.opacity(0.6) : Color.KlymbAccent.primary.opacity(0.32),
                    lineWidth: 1
                )
        )
        .fixedSize()
        .accessibilityLabel("\(streakDays) day streak")
    }
}

#Preview {
    HStack(spacing: 16) {
        StreakFlameView(streakDays: 14)
        StreakFlameView(streakDays: 21, isAtRisk: true)
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
