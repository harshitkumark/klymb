//
//  SecondaryButton.swift
//  klymb
//
//  Architectural secondary button matching the matte charcoal & bone ink system.
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
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(Font.Klymb.headline)
            }
            .foregroundStyle(isEnabled ? Color.KlymbText.primary : Color.KlymbAccent.disabledText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(Color.KlymbBackground.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                    .strokeBorder(KlymbGradient.specularBorder, lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .disabled(!isEnabled)
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 14) {
        SecondaryButton("Leave Challenge", icon: "xmark") {}
        SecondaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
