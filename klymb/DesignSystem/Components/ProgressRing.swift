//
//  ProgressRing.swift
//  klymb
//
//  Circular progress ring matching docs/DESIGN_SYSTEM.md §9.5.
//  Supports stroke animations and accessibility Reduce Motion.
//

import SwiftUI

public struct ProgressRing<CenterContent: View>: View {
    public let progress: Double // 0.0 to 1.0 (or greater)
    public let size: CGFloat
    public let strokeWidth: CGFloat
    public let centerContent: CenterContent

    @State private var animatedProgress: Double = 0.0

    public init(
        progress: Double,
        size: CGFloat = 120,
        strokeWidth: CGFloat = 10,
        @ViewBuilder centerContent: () -> CenterContent = { EmptyView() }
    ) {
        self.progress = progress
        self.size = size
        self.strokeWidth = strokeWidth
        self.centerContent = centerContent()
    }

    public var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.KlymbBackground.tertiary, lineWidth: strokeWidth)
                .frame(width: size, height: size)

            // Progress stroke (first lap up to 100%)
            Circle()
                .trim(from: 0, to: CGFloat(min(animatedProgress, 1.0)))
                .stroke(
                    KlymbGradient.accent,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)

            // Over 100%: Second lap in purple accent
            if animatedProgress > 1.0 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(animatedProgress - 1.0, 1.0)))
                    .stroke(
                        Color.KlymbAccent.secondary,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
            }

            // Center Content
            centerContent
        }
        .onAppear {
            if UIAccessibility.isReduceMotionEnabled {
                animatedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newProgress in
            if UIAccessibility.isReduceMotionEnabled {
                animatedProgress = newProgress
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedProgress = newProgress
                }
            }
        }
        .accessibilityLabel("\(Int(progress * 100)) percent completed")
    }
}

#Preview {
    VStack(spacing: 32) {
        ProgressRing(progress: 0.75, size: 120, strokeWidth: 10) {
            VStack {
                Text("75%")
                    .font(Font.Klymb.titleMedium)
                Text("KP Cap")
                    .font(Font.Klymb.caption)
                    .foregroundStyle(Color.KlymbText.secondary)
            }
        }

        ProgressRing(progress: 1.25, size: 80, strokeWidth: 8) {
            Text("125%")
                .font(Font.Klymb.headline)
        }
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
