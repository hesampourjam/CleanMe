import AppKit
import SwiftUI

struct AppDetailView: View {
    @EnvironmentObject private var state: AppState
    let app: InstalledApp

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                hero
                statsStrip
                leftoversSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            AppIconView(url: app.url)
                .frame(width: 84, height: 84)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(app.name)
                    .font(.system(size: 26, weight: .bold))
                HStack(spacing: 6) {
                    if let v = app.version {
                        PillBadge(text: "v\(v)", tint: Theme.accent)
                    }
                    if app.isSystemProtected {
                        PillBadge(text: "System", tint: .orange)
                    }
                }
                Text(app.bundleID.isEmpty ? "No bundle identifier" : app.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            Button(role: .destructive) {
                state.beginUninstall(app: app)
            } label: {
                Label("Remove", systemImage: "trash.fill")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(app.isSystemProtected)
            .help(app.isSystemProtected ? "System apps cannot be removed" : "Move this app and its files to the Trash")
        }
    }

    // MARK: - Stats

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(
                label: "App size",
                value: formatBytes(app.sizeBytes),
                symbol: "shippingbox.fill",
                tint: Theme.accent
            )
            divider
            statCell(
                label: "Related items",
                value: "\(state.leftovers.count)",
                symbol: "doc.on.doc.fill",
                tint: Color(red: 0.55, green: 0.50, blue: 0.90)
            )
            divider
            statCell(
                label: "Reclaimable",
                value: formatBytes(reclaimableBytes),
                symbol: "sparkles",
                tint: Color(red: 0.40, green: 0.75, blue: 0.50)
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .cardBackground()
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 32)
    }

    private func statCell(label: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            TintedIcon(systemName: symbol, tint: tint, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.callout.monospacedDigit().weight(.semibold))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var reclaimableBytes: Int64 {
        (app.sizeBytes ?? 0) + state.selectedLeftovers.reduce(0) { $0 + $1.sizeBytes }
    }

    private func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Leftovers

    @ViewBuilder private var leftoversSection: some View {
        if state.isLoadingLeftovers {
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Looking for related files…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else if state.leftovers.isEmpty {
            EmptyStateView(
                "Nothing else to clean",
                systemImage: "sparkles",
                message: "Only the app bundle itself will be moved to the Trash.",
                tint: Color(red: 0.40, green: 0.75, blue: 0.50)
            )
            .frame(minHeight: 180)
        } else {
            leftoverGroups
        }
    }

    private var leftoverGroups: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Related files")
                    .font(.title3.weight(.semibold))
                Text("\(state.selectedLeftovers.count) of \(state.leftovers.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Select all") { state.setAllLeftovers(selected: true) }
                    .buttonStyle(.borderless)
                Text("·").foregroundStyle(.secondary)
                Button("Clear") { state.setAllLeftovers(selected: false) }
                    .buttonStyle(.borderless)
            }

            ForEach(groupedLeftovers, id: \.0) { kind, files in
                LeftoverGroupCard(kind: kind, files: files)
            }
        }
    }

    private var groupedLeftovers: [(AssociatedFileKind, [AssociatedFile])] {
        let grouped = Dictionary(grouping: state.leftovers, by: \.kind)
        return AssociatedFileKind.allCases.compactMap { kind in
            guard let files = grouped[kind], !files.isEmpty else { return nil }
            return (kind, files.sorted { $0.url.path < $1.url.path })
        }
    }
}

// MARK: - Group card

private struct LeftoverGroupCard: View {
    @EnvironmentObject private var state: AppState
    let kind: AssociatedFileKind
    let files: [AssociatedFile]

    private var totalBytes: Int64 { files.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.hairline)
            VStack(spacing: 0) {
                ForEach(Array(files.enumerated()), id: \.offset) { idx, file in
                    LeftoverRow(file: file)
                    if idx < files.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                            .padding(.leading, 44)
                    }
                }
            }
        }
        .cardBackground()
    }

    private var header: some View {
        HStack(spacing: 10) {
            TintedIcon(systemName: symbol(for: kind), tint: Theme.tint(for: kind), size: 26)
            Text(kind.displayName)
                .font(.callout.weight(.semibold))
            Spacer()
            Text("\(files.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("·").foregroundStyle(.secondary)
            Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func symbol(for kind: AssociatedFileKind) -> String {
        switch kind {
        case .preferences:        return "slider.horizontal.3"
        case .caches:             return "internaldrive.fill"
        case .applicationSupport: return "folder.fill"
        case .containers:         return "shippingbox.fill"
        case .groupContainers:    return "shippingbox.and.arrow.backward.fill"
        case .launchAgents:       return "bolt.fill"
        case .launchDaemons:      return "bolt.shield.fill"
        case .logs:               return "doc.text.fill"
        case .savedState:         return "clock.fill"
        case .httpStorages:       return "globe"
        case .webKit:             return "safari.fill"
        case .appBundle:          return "app.fill"
        case .other:              return "doc.fill"
        }
    }
}

// MARK: - Row

private struct LeftoverRow: View {
    @EnvironmentObject private var state: AppState
    let file: AssociatedFile

    var body: some View {
        let isSelected = !state.deselectedLeftoverURLs.contains(file.url)

        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { isSelected },
                    set: { _ in state.toggle(file) }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(file.requiresAdmin)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(file.url.deletingLastPathComponent().path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if file.requiresAdmin {
                PillBadge(text: "Admin", tint: .orange)
            }

            Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 68, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
        }
    }
}
