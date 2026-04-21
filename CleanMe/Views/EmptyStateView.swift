import SwiftUI

/// macOS 13-compatible replacement for `ContentUnavailableView` with a premium look:
/// tinted circular icon, strong title, and a muted message beneath.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String?
    let tint: Color

    init(_ title: String, systemImage: String, message: String? = nil, tint: Color = .accentColor) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.tint = tint
    }

    var body: some View {
        VStack(spacing: 14) {
            TintedIcon(systemName: systemImage, tint: tint, size: 72)
            Text(title)
                .font(.title3.weight(.semibold))
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
