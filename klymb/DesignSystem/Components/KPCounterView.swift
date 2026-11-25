//
//  KPCounterView.swift
//  klymb
//
//  Rolling KP counter with condensed athletic tabular numerals and Reduce Motion support.
//

import SwiftUI

public struct KPCounterView: View {
    public let targetValue: Int
    public let prefix: String?
    public let font: Font
    public let color: Color

    @State private var displayValue: Int = 0
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        value: Int,
        prefix: String? = nil,
        font: Font = Font.Klymb.kpCounter,
        color: Color = Color.KlymbText.primary
    ) {
        self.targetValue = value
        self.prefix = prefix
        self.font = font
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 2) {
            if let prefix {
                Text(prefix)
                    .font(font)
                    .foregroundStyle(color)
            }

            Text(formattedValue(displayValue))
                .font(font)
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(displayValue)))
        }
        .onAppear {
            animateValue(to: targetValue)
        }
        .onChange(of: targetValue) { _, newValue in
            animateValue(to: newValue)
        }
        .onDisappear {
            animationTask?.cancel()
        }
        .accessibilityLabel("\(prefix ?? "") \(targetValue) Klymb Points")
    }

    private func formattedValue(_ value: Int) -> String {
        value.formatted()
    }

    private func animateValue(to target: Int) {
        animationTask?.cancel()

        if reduceMotion || UIAccessibility.isReduceMotionEnabled {
            displayValue = target
            return
        }

        let start = displayValue
        let diff = target - start
        guard diff != 0 else { return }

        let steps = min(abs(diff), 20)
        let stepIntervalNs = UInt64((0.55 / Double(steps)) * 1_000_000_000)

        animationTask = Task { @MainActor in
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: stepIntervalNs)
                if Task.isCancelled { return }
                let progress = Double(i) / Double(steps)
                let eased = 1 - pow(1 - progress, 3)
                withAnimation(.easeOut(duration: 0.08)) {
                    self.displayValue = start + Int(Double(diff) * eased)
                }
            }
            if !Task.isCancelled {
                self.displayValue = target
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        KPCounterView(value: 1247)
        KPCounterView(value: 114, prefix: "+", color: Color.KlymbAccent.soft)
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
