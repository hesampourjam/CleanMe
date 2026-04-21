import AppKit
import SwiftUI

struct AppListView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            if state.isScanning && state.apps.isEmpty {
                scanning
            } else if state.filteredApps.isEmpty && !state.searchQuery.isEmpty {
                EmptyStateView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    message: "Nothing matches “\(state.searchQuery)”. Try a different name or bundle ID.",
                    tint: Theme.accent
                )
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await state.rescan() }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .help("Scan installed apps")
                .disabled(state.isScanning)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Applications")
                .font(.title2.weight(.bold))
            Text("^[\(state.apps.count) app](inflect: true) on this Mac")
                .font(.caption)
                .foregroundStyle(.secondary)
            searchField
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Search apps", text: $state.searchQuery)
                .textFieldStyle(.plain)
            if !state.searchQuery.isEmpty {
                Button {
                    state.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.cardStroke, lineWidth: 1)
        )
    }

    private var scanning: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Scanning apps…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List(selection: Binding(
            get: { state.selectedAppID },
            set: { newID in Task { await state.select(appID: newID) } }
        )) {
            ForEach(state.filteredApps) { app in
                AppRow(app: app, isSelected: app.id == state.selectedAppID)
                    .tag(app.id as InstalledApp.ID?)
                    .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(url: app.url)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(app.bundleID.isEmpty ? "No bundle ID" : app.bundleID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            if let size = app.sizeBytes {
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(isSelected ? Theme.cardFillSelected : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

/// Loads the Finder icon for an app bundle. Falls back to a generic system icon.
struct AppIconView: View {
    let url: URL

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
    }
}
