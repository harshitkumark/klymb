//
//  OfflineBannerView.swift
//  klymb
//
//  Floating translucent banner displayed when device is offline.
//

import SwiftUI

public struct OfflineBannerView: View {
    public init() {}

    public var body: some View {
        KlymbToastBanner(
            icon: "wifi.slash",
            message: "Offline — activities queued locally to sync later.",
            trailingLabel: "QUEUED",
            accentColor: Color.KlymbSemantic.warning
        )
        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline mode. Activities are queued locally and will sync once reconnected.")
    }
}

#Preview {
    ZStack {
        Color.KlymbBackground.primary.ignoresSafeArea()
        VStack {
            OfflineBannerView()
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
