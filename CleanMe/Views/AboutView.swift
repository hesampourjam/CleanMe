import AppKit
import SwiftUI

struct AboutView: View {
    @State private var showDevLinks = false

    private var versionLine: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = (info["CFBundleShortVersionString"] as? String) ?? "0.0.0"
        let build = (info["CFBundleVersion"] as? String) ?? "0"
        return "Version \(short) · Build \(build)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                hero
                supportSection
                disclosureSection
                footer
            }
            .padding(36)
            .frame(maxWidth: 580)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            Text("CleanMe")
                .font(.system(size: 32, weight: .bold))
            Text(versionLine)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("A premium uninstaller for macOS. Free, forever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    // MARK: - Support

    private var supportSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Enjoying CleanMe?")
                    .font(.headline)
                Text("It's built and maintained by one person in their spare time. A small tip keeps it going.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                SupportButton(
                    title: "Buy me a coffee",
                    systemImage: "cup.and.saucer.fill",
                    background: Color(red: 1.0, green: 0.867, blue: 0.0),
                    foreground: .black,
                    url: URL(string: "https://buymeacoffee.com/hepour")!
                )
                SupportButton(
                    title: "GitHub Sponsors",
                    systemImage: "heart.fill",
                    background: Color(red: 0.85, green: 0.3, blue: 0.5),
                    foreground: .white,
                    url: URL(string: "https://github.com/sponsors/hesampourjam")!
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardBackground()
    }

    // MARK: - Disclosure

    private var disclosureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showDevLinks.toggle() }
            } label: {
                HStack {
                    Text("For developers & curious minds")
                        .font(.callout.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showDevLinks ? 90 : 0))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showDevLinks {
                VStack(alignment: .leading, spacing: 2) {
                    linkRow("Source on GitHub",    "https://github.com/hesampourjam/CleanMe",                          symbol: "chevron.left.forwardslash.chevron.right")
                    linkRow("Report an issue",     "https://github.com/hesampourjam/CleanMe/issues/new",               symbol: "exclamationmark.bubble.fill")
                    linkRow("Privacy policy",      "https://github.com/hesampourjam/CleanMe#privacy",                  symbol: "hand.raised.fill")
                    linkRow("Acknowledgements",    "https://github.com/hesampourjam/CleanMe#acknowledgements",         symbol: "sparkles")
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardBackground()
    }

    private func linkRow(_ title: String, _ url: String, symbol: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.callout)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)
                Text(title).font(.callout)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("Made with")
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red.opacity(0.7))
                Text("in Vancouver, BC")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("© 2026 CleanMe")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }
}

private struct SupportButton: View {
    let title: String
    let systemImage: String
    let background: Color
    let foreground: Color
    let url: URL

    @State private var isHovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title).font(.callout.weight(.semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.black.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .shadow(color: background.opacity(isHovering ? 0.35 : 0), radius: 10, y: 4)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
