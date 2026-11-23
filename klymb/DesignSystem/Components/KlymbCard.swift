//
//  KlymbCard.swift
//  klymb
//
//  Card container matching docs/DESIGN_SYSTEM.md §9.3.
//

import SwiftUI

public struct KlymbCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let isHighlighted: Bool
    public let content: Content

    public init(
        cornerRadius: CGFloat = KlymbRadius.xl,
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.content = content()
    }

    public var body: some View {
        content
            .padding(KlymbSpacing.lg)
            .klymbCardStyle(cornerRadius: cornerRadius, isHighlighted: isHighlighted)
    }
}

#Preview {
    KlymbCard(isHighlighted: true) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Goal")
                .font(Font.Klymb.headline)
            Text("10,000 steps")
                .font(Font.Klymb.titleMedium)
                .foregroundStyle(Color.KlymbAccent.primary)
        }
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
