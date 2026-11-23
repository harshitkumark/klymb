//
//  RankBadge.swift
//  klymb
//
//  Tiered leaderboard rank badge matching docs/DESIGN_SYSTEM.md §9.4.
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
                        .stroke(badgeBorderColor, lineWidth: isTopThree ? 2.0 : 1.0)
                )

            if rank <= 3 {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(badgeTextColor)
                    .offset(y: -size * 0.52)
            }

            Text("#\(rank)")
                .font(.system(size: size * 0.38, weight: .bold, design: .monospaced))
                .foregroundStyle(badgeTextColor)
                .minimumScaleFactor(0.7)
        }
        .accessibilityLabel("Rank \(rank)")
    }

    private var isTopThree: Bool {
        rank >= 1 && rank <= 3
    }

    private var badgeBackground: AnyShapeStyle {
        switch rank {
        case 1:
            return AnyShapeStyle(Color.KlymbRank.gold.opacity(0.25))
        case 2:
            return AnyShapeStyle(Color.KlymbRank.silver.opacity(0.25))
        case 3:
            return AnyShapeStyle(Color.KlymbRank.bronze.opacity(0.25))
        case 4...10:
            return AnyShapeStyle(Color.KlymbAccent.primaryMuted)
        default:
            return AnyShapeStyle(Color.KlymbBackground.tertiary)
        }
    }

    private var badgeBorderColor: Color {
        switch rank {
        case 1: return Color.KlymbRank.gold
        case 2: return Color.KlymbRank.silver
        case 3: return Color.KlymbRank.bronze
        case 4...10: return Color.KlymbAccent.primary
        default: return Color.KlymbBorder.default
        }
    }

    private var badgeTextColor: Color {
        switch rank {
        case 1: return Color.KlymbRank.gold
        case 2: return Color.KlymbRank.silver
        case 3: return Color.KlymbRank.bronze
        case 4...10: return Color.KlymbAccent.primary
        default: return Color.KlymbText.secondary
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        RankBadge(rank: 1, size: 48)
        RankBadge(rank: 2, size: 48)
        RankBadge(rank: 3, size: 48)
        RankBadge(rank: 7, size: 48)
        RankBadge(rank: 42, size: 48)
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
