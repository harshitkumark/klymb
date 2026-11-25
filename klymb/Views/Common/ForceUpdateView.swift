//
//  ForceUpdateView.swift
//  klymb
//
//  Blocking modal view displayed when current build is below minimum supported version.
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
        ZStack(alignment: .top) {
            Color.KlymbBackground.primary.ignoresSafeArea()
            KlymbTopographicBackdrop(accentOpacity: 0.06)
                .ignoresSafeArea()

            VStack(spacing: KlymbSpacing.lg) {
                Spacer()

                KlymbBrandMark(size: 36)

                VStack(spacing: 8) {
                    Text("UPDATE REQUIRED")
                        .font(Font.Klymb.telemetry)
                        .foregroundStyle(Color.KlymbAccent.soft)
                        .tracking(1.6)

                    Text("Upgrade to Keep Climbing")
                        .font(Font.Klymb.titleLarge)
                        .foregroundStyle(Color.KlymbText.primary)
                        .multilineTextAlignment(.center)

                    Text("A newer version of Klymb is required to continue syncing activities, calculating KP, and competing on leaderboards.")
                        .font(Font.Klymb.bodySmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                }

                if let notes = versionInfo.releaseNotes {
                    KlymbCard(padding: KlymbSpacing.lg) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHAT'S NEW IN v\(versionInfo.minSupportedVersion)")
                                .font(Font.Klymb.telemetry)
                                .foregroundStyle(Color.KlymbAccent.soft)

                            Text(notes)
                                .font(Font.Klymb.caption)
                                .foregroundStyle(Color.KlymbText.secondary)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                }

                Spacer()

                VStack(spacing: KlymbSpacing.md) {
                    PrimaryButton("Update via App Store", icon: "arrow.down.app.fill") {
                        UIApplication.shared.open(versionInfo.appStoreURL)
                    }

                    #if DEBUG
                    if let onDismiss {
                        Button("Developer Mode: Dismiss Screen", action: onDismiss)
                            .font(Font.Klymb.caption)
                            .foregroundStyle(Color.KlymbText.tertiary)
                    }
                    #endif
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.bottom, KlymbSpacing.lg)
            }
        }
    }
}

#Preview {
    ForceUpdateView()
        .preferredColorScheme(.dark)
}
