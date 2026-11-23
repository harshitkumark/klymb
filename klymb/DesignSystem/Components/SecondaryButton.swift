//
//  SecondaryButton.swift
//  klymb
//
//  Outlined Secondary Button matching docs/DESIGN_SYSTEM.md §9.2.
//

import SwiftUI

public struct SecondaryButton: View {
    public let title: String
    public let icon: String?
    public let isEnabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: {
            guard isEnabled else { return }
            HapticManager.shared.buttonTap()
            action()
        }) {
            HStack(spacing: KlymbSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(Font.Klymb.headline)
            }
            .foregroundStyle(Color.KlymbAccent.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: KlymbRadius.lg)
                    .stroke(Color.KlymbAccent.primary, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg))
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .disabled(!isEnabled)
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 16) {
        SecondaryButton("View Rules", icon: "doc.text") {}
        SecondaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
