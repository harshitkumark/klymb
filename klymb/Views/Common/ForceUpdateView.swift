//
//  ForceUpdateView.swift
//  klymb
//
//  Blocking modal view displayed when the current build is below the minimum
//  supported version requirement (PRD §F16 & Design System §9.12).
//  Follows AGENTS.md Rules 15, 18.
//

import SwiftUI

public struct ForceUpdateView: View {
    public let versionInfo: AppVersionInfo
    public var onDismiss: (() -> Void)?

    public init(
        versionInfo: AppVersionInfo = AppVersionInfo(),
        onDismiss: (() -> Void)? = nil
    ) {
        self.versionInfo = versionInfo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            ColorTokens.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: LayoutTokens.spacingL) {
                Spacer()

                // Glow Emblem
                ZStack {
                    Circle()
                        .fill(ColorTokens.electricCyan.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(ColorTokens.electricCyan)
                }
                .overlay(
                    Circle()
                        .strokeBorder(ColorTokens.electricCyan.opacity(0.4), lineWidth: 2)
                )

                // Title & Subtitle
                VStack(spacing: 8) {
                    Text("CRITICAL UPDATE REQUIRED")
                        .font(TypographyTokens.caption1.bold())
                        .foregroundStyle(ColorTokens.electricCyan)
                        .tracking(1.5)

                    Text("Upgrade to Keep Climbing")
                        .font(TypographyTokens.title1)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("A newer version of Klymb is required to continue syncing activities, calculating KP, and competing on leaderboards.")
                        .font(TypographyTokens.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                }

                // Release Notes Card
                if let notes = versionInfo.releaseNotes {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(ColorTokens.neonGreen)
                            Text("WHAT'S NEW IN v\(versionInfo.minSupportedVersion)")
                                .font(TypographyTokens.caption2.bold())
                                .foregroundStyle(ColorTokens.textSecondary)
                        }

                        Text(notes)
                            .font(TypographyTokens.caption1)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .lineSpacing(3)
                    }
                    .padding(LayoutTokens.paddingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                            .fill(ColorTokens.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                            .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
                    )
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                }

                Spacer()

                // Update Button
                VStack(spacing: LayoutTokens.spacingM) {
                    Button {
                        UIApplication.shared.open(versionInfo.appStoreURL)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.app.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Update via App Store")
                                .font(TypographyTokens.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(ColorTokens.electricCyan)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusL))
                    }
                    .buttonStyle(.plain)

                    #if DEBUG
                    if let onDismiss = onDismiss {
                        Button("Developer Mode: Dismiss Screen", action: onDismiss)
                            .font(TypographyTokens.caption1)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    #endif
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.bottom, LayoutTokens.spacingL)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ForceUpdateView()
}
