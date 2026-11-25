//
//  RankBadge.swift
//  klymb
//
//  Clean circular leaderboard rank crest matching the Matte Charcoal & Metallic system.
//

import SwiftUI

public struct RankBadge: View {
    public let rank: Int
    public let size: CGFloat

    public init(rank: Int, size: CGFloat = 36) {
        self.rank = rank
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(badgeBackground)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(badgeBorderColor, lineWidth: isTopThree ? 1.5 : 1.0)
                )

            Text("#\(rank)")
                .font(.system(size: max(11, size * 0.36), weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(badgeTextColor)
                .minimumScaleFactor(0.7)
        }
        .accessibilityLabel("Rank \(rank)")
    }

    private var isTopThree: Bool {
        rank >= 1 && rank <= 3
    }

    private var badgeBackground: Color {
        switch rank {
        case 1: return Color.KlymbRank.gold.opacity(0.16)
        case 2: return Color.KlymbRank.silver.opacity(0.14)
        case 3: return Color.KlymbRank.bronze.opacity(0.14)
        case 4...10: return Color.KlymbAccent.primaryMuted
        default: return Color.KlymbBackground.tertiary
        }
    }

    private var badgeBorderColor: Color {
        switch rank {
        case 1: return Color.KlymbRank.gold.opacity(0.7)
        case 2: return Color.KlymbRank.silver.opacity(0.6)
        case 3: return Color.KlymbRank.bronze.opacity(0.6)
        case 4...10: return Color.KlymbAccent.primary.opacity(0.45)
        default: return Color.KlymbBorder.default
        }
    }

    private var badgeTextColor: Color {
        switch rank {
        case 1: return Color.KlymbRank.gold
        case 2: return Color.KlymbRank.silver
        case 3: return Color.KlymbRank.bronze
        case 4...10: return Color.KlymbAccent.soft
        default: return Color.KlymbText.secondary
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        RankBadge(rank: 1, size: 44)
        RankBadge(rank: 2, size: 44)
        RankBadge(rank: 3, size: 44)
        RankBadge(rank: 7, size: 44)
        RankBadge(rank: 42, size: 44)
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
