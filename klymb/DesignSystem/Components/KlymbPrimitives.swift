//
//  KlymbPrimitives.swift
//  klymb
//
//  Shared minimalist UI primitives eliminating duplicated row/picker/progress boilerplate
//  across screens (Brand Mark, Topographic Backdrop, Sliding Segmented Control,
//  Vector Progress Bar, Floating Glass Toast, Grouped Containers, Icon Catalog).
//

import SwiftUI

// MARK: - 1. Geometric Klymb Ascent Logo Mark
public struct KlymbBrandMark: View {
    public let size: CGFloat
    public let accentColor: Color

    public init(size: CGFloat = 28, accentColor: Color = Color.KlymbAccent.primary) {
        self.size = size
        self.accentColor = accentColor
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                .fill(Color.KlymbBackground.tertiary)
                .frame(width: size * 1.65, height: size * 1.65)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                        .strokeBorder(KlymbGradient.specularBorder, lineWidth: 1)
                )

            KlymbMountainShape()
                .frame(width: size, height: size * 0.72)
        }
        .accessibilityHidden(true)
    }
}

private struct KlymbMountainShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var leftPeak = Path()
            leftPeak.move(to: CGPoint(x: w * 0.06, y: h * 0.92))
            leftPeak.addLine(to: CGPoint(x: w * 0.42, y: h * 0.14))
            leftPeak.addLine(to: CGPoint(x: w * 0.60, y: h * 0.52))

            var rightPeak = Path()
            rightPeak.move(to: CGPoint(x: w * 0.43, y: h * 0.92))
            rightPeak.addLine(to: CGPoint(x: w * 0.68, y: h * 0.34))
            rightPeak.addLine(to: CGPoint(x: w * 0.94, y: h * 0.92))

            let style = StrokeStyle(lineWidth: max(2.2, w * 0.105), lineCap: .round, lineJoin: .round)
            context.stroke(leftPeak, with: .color(Color.KlymbText.primary), style: style)
            context.stroke(rightPeak, with: .color(Color.KlymbAccent.primary), style: style)
        }
    }
}

// MARK: - 2. Subtle Topographic Elevation Canvas
public struct KlymbTopographicBackdrop: View {
    public var accentOpacity: Double

    public init(accentOpacity: Double = 0.075) {
        self.accentOpacity = accentOpacity
    }

    public var body: some View {
        ZStack(alignment: .top) {
            RadialGradient(
                colors: [
                    Color.KlymbAccent.primary.opacity(accentOpacity),
                    Color.KlymbAccent.primary.opacity(accentOpacity * 0.25),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.30),
                startRadius: 8,
                endRadius: 210
            )
            .frame(height: 380)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white, location: 0.18),
                        .init(color: .white, location: 0.65),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Canvas { context, size in
                let w = size.width
                let bands = 5
                for idx in 0..<bands {
                    let yOffset = 52.0 + Double(idx) * 32.0
                    let fade = 0.14 - Double(idx) * 0.025
                    var path = Path()
                    path.move(to: CGPoint(x: -16, y: yOffset + 22))
                    path.addCurve(
                        to: CGPoint(x: w * 0.54, y: yOffset - 10),
                        control1: CGPoint(x: w * 0.18, y: yOffset - 14),
                        control2: CGPoint(x: w * 0.34, y: yOffset + 34)
                    )
                    path.addCurve(
                        to: CGPoint(x: w + 16, y: yOffset - 18),
                        control1: CGPoint(x: w * 0.72, y: yOffset - 46),
                        control2: CGPoint(x: w * 0.86, y: yOffset + 12)
                    )
                    let lineColor = idx == bands - 1
                        ? Color.KlymbAccent.primary.opacity(0.14)
                        : Color.KlymbText.primary.opacity(max(0.02, fade))
                    context.stroke(path, with: .color(lineColor), lineWidth: 1.0)
                }
            }
            .frame(height: 260)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 3. Sliding Segmented Control (Replaces UIKit gray picker & duplicated bars)
public struct KlymbSegmentedControl<Option: Identifiable & Hashable>: View {
    public let options: [Option]
    @Binding public var selection: Option
    public let title: (Option) -> String
    public let icon: ((Option) -> String)?
    public let badgeCount: ((Option) -> Int)?
    public let accentSelectionText: Bool
    public let onSelect: ((Option) -> Void)?

    @Namespace private var pillNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        options: [Option],
        selection: Binding<Option>,
        title: @escaping (Option) -> String,
        icon: ((Option) -> String)? = nil,
        badgeCount: ((Option) -> Int)? = nil,
        accentSelectionText: Bool = false,
        onSelect: ((Option) -> Void)? = nil
    ) {
        self.options = options
        self._selection = selection
        self.title = title
        self.icon = icon
        self.badgeCount = badgeCount
        self.accentSelectionText = accentSelectionText
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                let isSelected = option == selection
                let count = badgeCount?(option) ?? 0

                Button {
                    if let onSelect {
                        onSelect(option)
                    } else {
                        selection = option
                        HapticManager.selection()
                    }
                } label: {
                    HStack(spacing: 5) {
                        if let icon {
                            Image(systemName: icon(option))
                                .font(.system(size: 12, weight: .semibold))
                        }

                        Text(title(option))
                            .font(Font.Klymb.bodySmall.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.KlymbText.inverse)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.KlymbAccent.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(
                        isSelected
                            ? (accentSelectionText ? Color.KlymbAccent.soft : Color.KlymbText.primary)
                            : Color.KlymbText.secondary
                    )
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.KlymbBackground.elevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(KlymbGradient.specularBorder, lineWidth: 1)
                                )
                                .matchedGeometryEffect(id: "klymb_segment_pill", in: pillNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Color.KlymbBackground.secondary)
        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                .strokeBorder(Color.KlymbBorder.default, lineWidth: 1)
        )
        .animation(reduceMotion ? nil : MotionTokens.springSnappy, value: selection)
    }
}

// MARK: - 4. Crisp Vector Progress Bar (Replaces blurry scaled ProgressView)
public struct KlymbProgressBar: View {
    public let progress: Double
    public let height: CGFloat
    public let isCompleted: Bool
    public let fillOverride: LinearGradient?

    public init(
        progress: Double,
        height: CGFloat = 4,
        isCompleted: Bool = false,
        fillOverride: LinearGradient? = nil
    ) {
        self.progress = min(1.0, max(0.0, progress))
        self.height = height
        self.isCompleted = isCompleted
        self.fillOverride = fillOverride
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.KlymbBackground.tertiary)
                    .frame(height: height)

                if progress > 0 {
                    Capsule()
                        .fill(barFill)
                        .frame(width: max(height, width * CGFloat(progress)), height: height)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private var barFill: AnyShapeStyle {
        if let fillOverride {
            return AnyShapeStyle(fillOverride)
        }
        if isCompleted {
            return AnyShapeStyle(Color.KlymbSemantic.success)
        }
        return AnyShapeStyle(KlymbGradient.accent)
    }
}

// MARK: - 5. Grouped Surface Container (Unifies stacked list items cleanly)
public struct KlymbGroupedSurface<Content: View>: View {
    public let cornerRadius: CGFloat
    public let content: Content

    public init(
        cornerRadius: CGFloat = KlymbRadius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
        }
        .klymbCardStyle(cornerRadius: cornerRadius)
    }
}

// MARK: - 6. Quiet Section Header
public struct KlymbSectionHeader: View {
    public let title: String
    public let trailingText: String?
    public let trailingColor: Color

    public init(
        _ title: String,
        trailingText: String? = nil,
        trailingColor: Color = Color.KlymbAccent.soft
    ) {
        self.title = title
        self.trailingText = trailingText
        self.trailingColor = trailingColor
    }

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(Font.Klymb.telemetry)
                .tracking(1.1)
                .foregroundStyle(Color.KlymbText.secondary)

            Spacer()

            if let trailingText {
                Text(trailingText)
                    .font(Font.Klymb.telemetry)
                    .foregroundStyle(trailingColor)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - 7. Floating Glass Toast Banner
public struct KlymbToastBanner: View {
    public let icon: String
    public let message: String
    public let trailingLabel: String?
    public let accentColor: Color

    public init(
        icon: String = "checkmark.circle.fill",
        message: String,
        trailingLabel: String? = nil,
        accentColor: Color = Color.KlymbSemantic.success
    ) {
        self.icon = icon
        self.message = message
        self.trailingLabel = trailingLabel
        self.accentColor = accentColor
    }

    public var body: some View {
        HStack(spacing: KlymbSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(message)
                .font(Font.Klymb.caption.weight(.semibold))
                .foregroundStyle(Color.KlymbText.primary)
                .lineLimit(2)

            Spacer(minLength: 8)

            if let trailingLabel {
                Text(trailingLabel)
                    .font(Font.Klymb.telemetry)
                    .foregroundStyle(Color.KlymbAccent.soft)
            }
        }
        .padding(.horizontal, KlymbSpacing.lg)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial)
        .background(Color.KlymbBackground.elevated.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 14, y: 6)
    }
}

// MARK: - 8. Shared Icon & Emblem Catalog (Single Source of Truth)
public enum KlymbIconCatalog {
    public static func habitIcon(for key: String) -> String {
        switch key {
        case "steps": return "figure.walk"
        case "running": return "figure.run"
        case "walking_distance": return "figure.walk.motion"
        case "workout": return "dumbbell.fill"
        case "hydration", "water": return "drop.fill"
        case "sleep": return "moon.fill"
        case "mindfulness": return "brain.head.profile"
        default: return "flame.fill"
        }
    }

    public static func avatarIcon(for preset: String?) -> String {
        switch preset {
        case "sprinter", "flame": return "flame.fill"
        case "climber": return "figure.climbing"
        case "cyclist": return "figure.outdoor.cycle"
        case "zen": return "figure.mind.and.body"
        case "star": return "star.fill"
        case "bolt": return "bolt.fill"
        case "shield": return "shield.fill"
        case "crown": return "crown.fill"
        case "heart": return "heart.fill"
        case "figure.run": return "figure.run"
        default: return "figure.run"
        }
    }
}
