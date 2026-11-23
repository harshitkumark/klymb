//
//  OfflineBannerView.swift
//  klymb
//
//  Floating notification banner displayed when the device is disconnected from
//  the internet (PRD §F16 & Design System §9.12).
//  Follows AGENTS.md Rules 15, 18.
//

import SwiftUI

public struct OfflineBannerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        HStack(spacing: LayoutTokens.spacingM) {
            ZStack {
                Circle()
                    .fill(ColorTokens.neonOrange.opacity(0.2))
                    .frame(width: 28, height: 28)

                Image(systemName: "wifi.slash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ColorTokens.neonOrange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("OFFLINE MODE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(ColorTokens.neonOrange)
                    .tracking(1)

                Text("Activities are queued locally and will sync once reconnected.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.neonOrange.opacity(0.8))
        }
        .padding(.horizontal, LayoutTokens.paddingM)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .fill(ColorTokens.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .strokeBorder(ColorTokens.neonOrange.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline mode. Activities are queued locally and will sync once reconnected.")
    }
}

#Preview {
    ZStack {
        ColorTokens.backgroundPrimary.ignoresSafeArea()
        VStack {
            OfflineBannerView()
            Spacer()
        }
    }
}
