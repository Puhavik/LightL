import SwiftUI
import AppKit

// MARK: - macOS 27 Design System & Liquid Glass 2.0 Specifications

public struct MacOS27LiquidGlass: ViewModifier {
    public var cornerRadius: CGFloat = 18
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectView(material: .popover, blendingMode: .behindWindow, cornerRadius: cornerRadius)
                    
                    // Liquid Glass meta-material dynamic tint
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45),
                            Color.white.opacity(colorScheme == .dark ? 0.02 : 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                // Refined dual-edge lensing (macOS 27 HIG depth refinement)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.35 : 0.7), location: 0.0),
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.3), location: 0.4),
                                .init(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18),
                radius: 20,
                x: 0,
                y: 10
            )
    }
}

// MARK: - macOS 27 Content Card (Golden Rule: content layer on high-contrast surface)

public struct MacOS27ContentCard: ViewModifier {
    public var cornerRadius: CGFloat = 12
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.70 : 0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4), location: 0.0),
                                .init(color: Color.primary.opacity(0.06), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - macOS 27 Glass Keycap

public struct MacOS27Keycap: View {
    public let glyph: String
    @Environment(\.colorScheme) private var colorScheme

    public init(_ glyph: String) {
        self.glyph = glyph
    }

    public var body: some View {
        Text(glyph)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.primary.opacity(0.9))
            .padding(.horizontal, glyph.count > 1 ? 6 : 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.8 : 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.35 : 0.7),
                                Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: 1.5,
                x: 0,
                y: 1
            )
    }
}

// MARK: - macOS 27 Glass Pill Button Style

public struct MacOS27GlassPillButtonStyle: ButtonStyle {
    public var isProminent: Bool = false
    public var role: ButtonRole? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    public init(isProminent: Bool = false, role: ButtonRole? = nil) {
        self.isProminent = isProminent
        self.role = role
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isProminent ? .semibold : .medium))
            .lineLimit(1)
            .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(Capsule(style: .continuous))
            .overlay(border(isPressed: configuration.isPressed))
            .shadow(
                color: shadowColor,
                radius: isProminent ? 6 : (isHovered ? 4 : 2),
                x: 0,
                y: isProminent ? 2 : 1
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        if isProminent {
            return .white
        }
        if role == .destructive {
            return .red
        }
        return .primary
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        if isProminent {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.45, blue: 0.95),
                    Color(red: 0.05, green: 0.32, blue: 0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(isPressed ? 0.85 : (isHovered ? 1.0 : 0.92))
        } else {
            ZStack {
                VisualEffectView(material: .selection, blendingMode: .withinWindow)
                    .opacity(0.3)
                
                Color(nsColor: .controlColor)
                    .opacity(isPressed ? 0.35 : (isHovered ? 0.22 : 0.12))
            }
        }
    }

    private func border(isPressed: Bool) -> some View {
        Capsule(style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(isProminent ? 0.45 : (colorScheme == .dark ? 0.25 : 0.6)), location: 0.0),
                        .init(color: Color.black.opacity(isProminent ? 0.2 : (colorScheme == .dark ? 0.35 : 0.12)), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }

    private var shadowColor: Color {
        if isProminent {
            return Color(red: 0.12, green: 0.45, blue: 0.95).opacity(0.35)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08)
    }
}

// MARK: - macOS 27 Status Indicator Badge

public struct MacOS27StatusBadge: View {
    public let title: String
    public let isSuccess: Bool
    public let icon: String?

    public init(title: String, isSuccess: Bool, icon: String? = nil) {
        self.title = title
        self.isSuccess = isSuccess
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isSuccess ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
                .shadow(color: (isSuccess ? Color.green : Color.orange).opacity(0.6), radius: 3, x: 0, y: 0)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill((isSuccess ? Color.green : Color.orange).opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke((isSuccess ? Color.green : Color.orange).opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - View Extension Convenience

public extension View {
    func macos27LiquidGlass(cornerRadius: CGFloat = 18) -> some View {
        self.modifier(MacOS27LiquidGlass(cornerRadius: cornerRadius))
    }

    func macos27ContentCard(cornerRadius: CGFloat = 12) -> some View {
        self.modifier(MacOS27ContentCard(cornerRadius: cornerRadius))
    }
}
