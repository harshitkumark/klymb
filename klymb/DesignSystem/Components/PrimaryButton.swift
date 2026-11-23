//
//  PrimaryButton.swift
//  klymb
//
//  Primary CTA Button matching docs/DESIGN_SYSTEM.md §9.1.
//  Gradient fill, loading spinner, press spring, and accessibility traits.
//

import SwiftUI

public struct PrimaryButton: View {
    public let title: String
    public let icon: String?
    public let isLoading: Bool
    public let isEnabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(title, icon: icon, isLoading: isLoading, isEnabled: isEnabled, action: action)
    }

    public var body: some View {
        Button(action: {
            guard isEnabled && !isLoading else { return }
            HapticManager.shared.buttonTap()
            action()
        }) {
            HStack(spacing: KlymbSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(Color.KlymbText.inverse)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                    }
                    Text(title)
                        .font(Font.Klymb.headline)
                }
            }
            .foregroundStyle(Color.KlymbText.inverse)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(KlymbGradient.accent)
            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg))
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

public struct KlymbPressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Start Climbing", icon: "arrow.up.right") {}
        PrimaryButton("Loading...", isLoading: true) {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
