import SwiftUI

/// Centralized visual tokens. Change values here to restyle app-wide.
enum Theme {
    // MARK: - Colors

    /// Tint pulled from the app icon. A confident, non-Apple blue.
    static let accent = Color(red: 0.30, green: 0.62, blue: 0.95)

    /// Subtle fill for card row backgrounds. Adapts to light/dark via opacity on .primary.
    static let cardFill = Color.primary.opacity(0.04)
    static let cardFillHover = Color.primary.opacity(0.07)
    static let cardFillSelected = Color.accentColor.opacity(0.14)
    static let cardStroke = Color.primary.opacity(0.06)

    /// Hairline divider stronger than `Divider()` but still quiet.
    static let hairline = Color.primary.opacity(0.08)

    // MARK: - Radii

    static let cardRadius: CGFloat = 10
    static let pillRadius: CGFloat = 6
    static let heroRadius: CGFloat = 14

    // MARK: - Spacing

    static let gutter: CGFloat = 18
    static let rowSpacing: CGFloat = 6
    static let sectionSpacing: CGFloat = 24

    // MARK: - Kind badges

    /// Accent tint for each leftover kind. Keeps groups visually distinct without being noisy.
    static func tint(for kind: AssociatedFileKind) -> Color {
        switch kind {
        case .preferences:        return Color(red: 0.30, green: 0.62, blue: 0.95) // blue
        case .caches:             return Color(red: 0.95, green: 0.60, blue: 0.20) // amber
        case .applicationSupport: return Color(red: 0.40, green: 0.75, blue: 0.50) // green
        case .containers:         return Color(red: 0.55, green: 0.50, blue: 0.90) // indigo
        case .groupContainers:    return Color(red: 0.45, green: 0.55, blue: 0.85) // slate blue
        case .launchAgents:       return Color(red: 0.95, green: 0.45, blue: 0.55) // rose
        case .launchDaemons:      return Color(red: 0.85, green: 0.35, blue: 0.35) // red
        case .logs:               return Color(red: 0.65, green: 0.65, blue: 0.70) // steel
        case .savedState:         return Color(red: 0.55, green: 0.70, blue: 0.85) // cyan
        case .httpStorages:       return Color(red: 0.70, green: 0.55, blue: 0.85) // violet
        case .webKit:             return Color(red: 0.35, green: 0.75, blue: 0.80) // teal
        case .appBundle:          return Color(red: 0.30, green: 0.62, blue: 0.95) // blue
        case .other:              return .secondary
        }
    }
}

// MARK: - Reusable modifiers

/// Pill-style metadata badge. Use for sizes, counts, "Admin" tags, etc.
struct PillBadge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.pillRadius))
    }
}

/// Soft circular backdrop behind an SF Symbol. Used for empty-state illustrations.
struct TintedIcon: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.15), in: Circle())
    }
}

/// Adds a card background with subtle stroke. Applied to groups in the leftover list.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
            )
    }
}

extension View {
    func cardBackground() -> some View { modifier(CardBackground()) }
}
