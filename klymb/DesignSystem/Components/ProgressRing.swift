//
//  ProgressRing.swift
//  klymb
//
//  Circular or open-arc sports-instrument telemetry gauge.
//  Supports optional outer perimeter tick marks, completion Mint shift, and Reduce Motion.
//

import SwiftUI

public struct ProgressRing<CenterContent: View>: View {
    public let progress: Double
    public let size: CGFloat
    public let strokeWidth: CGFloat
    public let openGauge: Bool
    public let showTicks: Bool
    public let centerContent: CenterContent

    @State private var animatedProgress: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let openArcSpan: Double = 250.0 / 360.0 // 250-degree sports instrument sweep

    public init(
        progress: Double,
        size: CGFloat = 120,
        strokeWidth: CGFloat = 8,
        openGauge: Bool = false,
        showTicks: Bool = false,
        @ViewBuilder centerContent: () -> CenterContent = { EmptyView() }
    ) {
        self.progress = progress
        self.size = size
        self.strokeWidth = strokeWidth
        self.openGauge = openGauge
        self.showTicks = showTicks
        self.centerContent = centerContent()
    }

    private var isCompleted: Bool {
        progress >= 1.0
    }

    private var ringDiameter: CGFloat {
        showTicks ? max(40, size - 26) : size
    }

    public var body: some View {
        ZStack {
            if showTicks {
                GaugeTickMarks(
                    progress: animatedProgress,
                    size: size,
                    isCompleted: isCompleted
                )
                .accessibilityHidden(true)
            }

            // Track
            Circle()
                .trim(from: 0, to: openGauge ? CGFloat(openArcSpan) : 1.0)
                .stroke(
                    Color.KlymbBackground.tertiary,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(openGauge ? 145 : -90))
                .frame(width: ringDiameter, height: ringDiameter)

            // Active Fill (Calm Mint when 100%, Warm Terracotta gradient while climbing)
            Circle()
                .trim(from: 0, to: CGFloat(min(animatedProgress, 1.0)) * CGFloat(openGauge ? openArcSpan : 1.0))
                .stroke(
                    isCompleted ? AnyShapeStyle(Color.KlymbSemantic.success) : AnyShapeStyle(KlymbGradient.accent),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(openGauge ? 145 : -90))
                .frame(width: ringDiameter, height: ringDiameter)

            centerContent
        }
        .frame(width: size, height: openGauge ? size * 0.88 : size)
        .onAppear {
            updateAnimatedProgress(to: progress)
        }
        .onChange(of: progress) { _, newProgress in
            updateAnimatedProgress(to: newProgress)
        }
        .accessibilityLabel("\(Int(min(progress, 1.0) * 100)) percent completed")
    }

    private func updateAnimatedProgress(to target: Double) {
        if reduceMotion || UIAccessibility.isReduceMotionEnabled {
            animatedProgress = target
        } else {
            withAnimation(.easeOut(duration: 0.7)) {
                animatedProgress = target
            }
        }
    }
}

private struct GaugeTickMarks: View {
    let progress: Double
    let size: CGFloat
    let isCompleted: Bool

    private let tickCount = 36

    var body: some View {
        ZStack {
            ForEach(0..<tickCount, id: \.self) { idx in
                let fraction = Double(idx) / Double(tickCount - 1)
                let angleDeg = -125.0 + fraction * 250.0
                let isLit = progress > 0 && fraction <= min(progress, 1.0)
                let isMajor = idx % 5 == 0

                Capsule()
                    .fill(
                        isLit
                            ? (isCompleted ? Color.KlymbSemantic.success : Color.KlymbAccent.soft)
                            : Color.KlymbBorder.default
                    )
                    .frame(width: isMajor ? 2.0 : 1.2, height: isMajor ? 7.5 : 4.5)
                    .offset(y: -(size / 2) + 4)
                    .rotationEffect(.degrees(angleDeg))
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 32) {
        ProgressRing(progress: 0.78, size: 196, strokeWidth: 7, openGauge: true, showTicks: true) {
            VStack(spacing: 2) {
                Text("KP TODAY")
                    .font(Font.Klymb.telemetry)
                    .foregroundStyle(Color.KlymbText.secondary)
                Text("1,247")
                    .font(.system(size: 46, weight: .heavy).width(.condensed))
                    .foregroundStyle(Color.KlymbText.primary)
            }
        }

        ProgressRing(progress: 1.0, size: 100, strokeWidth: 7) {
            Text("100%")
                .font(Font.Klymb.headline)
        }
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
