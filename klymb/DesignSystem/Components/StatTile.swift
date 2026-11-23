//
//  StatTile.swift
//  klymb
//
//  Compact statistical metric tile matching docs/DESIGN_SYSTEM.md §9.9.
//

import SwiftUI

public struct StatTile: View {
    public let icon: String
    public let value: String
    public let label: String
    public let valueColor: Color

    public init(
        icon: String,
        value: String,
        label: String,
        valueColor: Color = Color.KlymbAccent.primary
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.valueColor = valueColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KlymbSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(valueColor)
                .accessibilityHidden(true)

            Spacer(minLength: 4)

            Text(value)
                .font(Font.Klymb.titleSmall)
                .foregroundStyle(Color.KlymbText.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(Font.Klymb.caption)
                .foregroundStyle(Color.KlymbText.secondary)
                .lineLimit(1)
        }
        .padding(KlymbSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .klymbCardStyle(cornerRadius: KlymbRadius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    HStack(spacing: 12) {
        StatTile(icon: "figure.run", value: "42.5 km", label: "This Week")
        StatTile(icon: "flame.fill", value: "1,420", label: "KP Earned", valueColor: Color.KlymbSemantic.warning)
        StatTile(icon: "trophy.fill", value: "#14", label: "City Rank", valueColor: Color.KlymbRank.gold)
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
