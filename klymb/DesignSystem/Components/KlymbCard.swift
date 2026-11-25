//
//  KlymbCard.swift
//  klymb
//
//  Architectural dark-grey surface container with top-lit specular edge.
//

import SwiftUI

public struct KlymbCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let isHighlighted: Bool
    public let accentColor: Color
    public let padding: CGFloat
    public let isElevated: Bool
    public let content: Content

    public init(
        cornerRadius: CGFloat = KlymbRadius.lg,
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.accentColor = Color.KlymbAccent.primary
        self.padding = KlymbSpacing.lg
        self.isElevated = false
        self.content = content()
    }

    public init(
        glowColor: Color? = nil,
        cornerRadius: CGFloat = KlymbRadius.lg,
        padding: CGFloat = KlymbSpacing.lg,
        isHighlighted: Bool = false,
        isElevated: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isElevated = isElevated
        if let glowColor {
            self.accentColor = glowColor
            self.isHighlighted = true
        } else {
            self.accentColor = Color.KlymbAccent.primary
            self.isHighlighted = isHighlighted
        }
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .klymbCardStyle(
                cornerRadius: cornerRadius,
                isHighlighted: isHighlighted,
                accentColor: accentColor,
                isElevated: isElevated
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        KlymbCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily Goal")
                    .font(Font.Klymb.caption)
                    .foregroundStyle(Color.KlymbText.secondary)
                Text("10,000 steps")
                    .font(Font.Klymb.titleSmall)
                    .foregroundStyle(Color.KlymbText.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        KlymbCard(isHighlighted: true, isElevated: true) {
            Text("Elevated Highlighted Surface")
                .font(Font.Klymb.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
