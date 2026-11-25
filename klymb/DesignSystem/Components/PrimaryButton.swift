//
//  PrimaryButton.swift
//  klymb
//
//  Primary CTA Button with calm Bone White (default) and Velvet Terracotta tones,
//  accessible disabled state, and Reduce Motion support.
//

import SwiftUI

public enum PrimaryButtonTone {
    /// Calm Bone White fill with crisp dark ink — eliminates OLED glare on dark surfaces
    case bone
    /// Matte Velvet Terracotta accent fill with dark ink
    case terracotta
}

public struct PrimaryButton: View {
    public let title: String
    public let icon: String?
    public let tone: PrimaryButtonTone
    public let isLoading: Bool
    public let isEnabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        tone: PrimaryButtonTone = .bone,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tone = tone
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public init(
        title: String,
        icon: String? = nil,
        tone: PrimaryButtonTone = .bone,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(title, icon: icon, tone: tone, isLoading: isLoading, isEnabled: isEnabled, action: action)
    }

    private var foregroundColor: Color {
        guard isEnabled else { return Color.KlymbAccent.disabledText }
        return Color.KlymbText.inverse
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
                        .tint(foregroundColor)
                } else {
                    Text(title)
                        .font(Font.Klymb.headline)
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                    }
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                    .strokeBorder(
                        isEnabled ? Color.clear : Color.KlymbBorder.subtle,
                        lineWidth: 1
                    )
            )
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if !isEnabled {
            Color.KlymbAccent.disabledSurface
        } else {
            switch tone {
            case .bone:
                Color.KlymbAccent.boneCTA
            case .terracotta:
                Color.KlymbAccent.primary
            }
        }
    }
}

public struct KlymbPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect((configuration.isPressed && !reduceMotion) ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 14) {
        PrimaryButton("Create Account", icon: "arrow.right") {}
        PrimaryButton("Log Activity", icon: "plus", tone: .terracotta) {}
        PrimaryButton("Loading...", isLoading: true) {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
