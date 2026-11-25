//
//  StatTile.swift
//  klymb
//
//  Minimalist bento metric tile with label-first hierarchy and condensed tabular values.
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
        valueColor: Color = Color.KlymbText.primary
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.valueColor = valueColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KlymbSpacing.xs) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .accessibilityHidden(true)

                Text(label)
                    .font(Font.Klymb.caption)
                    .foregroundStyle(Color.KlymbText.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 2)

            Text(value)
                .font(Font.Klymb.athleticMetric)
                .foregroundStyle(Color.KlymbText.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
        StatTile(icon: "figure.run", value: "42.5 km", label: "This Week", valueColor: Color.KlymbAccent.soft)
        StatTile(icon: "flame.fill", value: "1,420", label: "KP Earned", valueColor: Color.KlymbAccent.primary)
        StatTile(icon: "trophy.fill", value: "#14", label: "City Rank", valueColor: Color.KlymbRank.gold)
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
