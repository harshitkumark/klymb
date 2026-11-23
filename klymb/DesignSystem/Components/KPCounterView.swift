//
//  KPCounterView.swift
//  klymb
//
//  Rolling KP counter matching docs/DESIGN_SYSTEM.md §6.2 & §9.6.
//  Animated count-up with monospaced digits and Reduce Motion support.
//

import SwiftUI

public struct KPCounterView: View {
    public let targetValue: Int
    public let prefix: String?
    public let font: Font
    public let color: Color

    @State private var displayValue: Int = 0

    public init(
        value: Int,
        prefix: String? = nil,
        font: Font = Font.Klymb.kpCounter,
        color: Color = Color.KlymbAccent.primary
    ) {
        self.targetValue = value
        self.prefix = prefix
        self.font = font
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 2) {
            if let prefix = prefix {
                Text(prefix)
                    .font(font)
                    .foregroundStyle(color)
            }

            Text("\(displayValue)")
                .font(font)
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(displayValue)))
        }
        .onAppear {
            animateValue(to: targetValue)
        }
        .onChange(of: targetValue) { _, newValue in
            animateValue(to: newValue)
        }
        .accessibilityLabel("\(prefix ?? "") \(targetValue) Klymb Points")
    }

    private func animateValue(to target: Int) {
        if UIAccessibility.isReduceMotionEnabled {
            displayValue = target
            return
        }

        let start = displayValue
        let diff = target - start
        guard diff != 0 else { return }

        let steps = min(abs(diff), 25)
        let stepDuration = 0.8 / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                let progress = Double(i) / Double(steps)
                let eased = 1 - pow(1 - progress, 3) // ease-out cubic
                self.displayValue = start + Int(Double(diff) * eased)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        KPCounterView(value: 1250)
        KPCounterView(value: 80, prefix: "+", color: Color.KlymbSemantic.success)
    }
    .padding()
    .background(Color.KlymbBackground.primary)
    .preferredColorScheme(.dark)
}
