import AppKit
import SwiftUI

struct ExtensionsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header
                content
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { if state.launchPlists.isEmpty { await state.loadLaunchPlists() } }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Extensions").font(.title.weight(.bold))
                Text("Background services, login items, and launch daemons running on this Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await state.loadLaunchPlists() }
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
                    .font(.callout.weight(.medium))
            }
            .controlSize(.large)
            .disabled(state.isLoadingLaunchPlists)
        }
    }

    @ViewBuilder private var content: some View {
        if state.isLoadingLaunchPlists {
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Scanning…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if state.launchPlists.isEmpty {
            EmptyStateView(
                "Nothing running in the background",
                systemImage: "puzzlepiece.extension.fill",
                message: "No launch agents or daemons were found.",
                tint: Color(red: 0.55, green: 0.50, blue: 0.90)
            )
            .frame(minHeight: 260)
        } else {
            VStack(spacing: 14) {
                ForEach(groupedByScope, id: \.scope) { group in
                    ScopeGroupCard(group: group)
                }
            }
        }
    }

    struct ScopeGroup {
        let scope: StartupItemsService.Scope
        let items: [StartupItemsService.LaunchPlist]
    }

    private var groupedByScope: [ScopeGroup] {
        let grouped = Dictionary(grouping: state.launchPlists, by: \.scope)
        let order: [StartupItemsService.Scope] = [.userAgent, .systemAgent, .systemDaemon]
        return order.compactMap { scope in
            guard let items = grouped[scope], !items.isEmpty else { return nil }
            return ScopeGroup(scope: scope, items: items)
        }
    }
}

private struct ScopeGroupCard: View {
    let group: ExtensionsView.ScopeGroup

    private var title: String {
        switch group.scope {
        case .userAgent: return "User launch agents"
        case .systemAgent: return "System launch agents"
        case .systemDaemon: return "Launch daemons"
        }
    }

    private var subtitle: String {
        switch group.scope {
        case .userAgent: return "~/Library/LaunchAgents"
        case .systemAgent: return "/Library/LaunchAgents"
        case .systemDaemon: return "/Library/LaunchDaemons"
        }
    }

    private var tint: Color {
        switch group.scope {
        case .userAgent: return Theme.accent
        case .systemAgent: return Color(red: 0.95, green: 0.45, blue: 0.55)
        case .systemDaemon: return Color(red: 0.85, green: 0.35, blue: 0.35)
        }
    }

    private var symbol: String {
        switch group.scope {
        case .userAgent: return "person.fill"
        case .systemAgent: return "bolt.fill"
        case .systemDaemon: return "bolt.shield.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                TintedIcon(systemName: symbol, tint: tint, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(subtitle).font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                if group.scope != .userAgent {
                    PillBadge(text: "Admin", tint: .orange)
                }
                Text("\(group.items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().overlay(Theme.hairline)

            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.offset) { idx, item in
                    ExtensionRow(item: item)
                    if idx < group.items.count - 1 {
                        Divider().overlay(Theme.hairline).padding(.leading, 14)
                    }
                }
            }
        }
        .cardBackground()
    }
}

private struct ExtensionRow: View {
    let item: StartupItemsService.LaunchPlist

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label ?? item.url.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(item.url.path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
    }
}
