import AppKit
import SwiftUI

struct OrphansView: View {
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
        .task { if state.orphans.isEmpty { await state.loadOrphans() } }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Orphaned Files").font(.title.weight(.bold))
                Text("Leftovers from apps you've already deleted. Safe to reclaim.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await state.loadOrphans() }
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
                    .font(.callout.weight(.medium))
            }
            .controlSize(.large)
            .disabled(state.isLoadingOrphans)
        }
    }

    @ViewBuilder private var content: some View {
        if state.isLoadingOrphans {
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Scanning…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if state.orphans.isEmpty {
            EmptyStateView(
                "No orphans found",
                systemImage: "checkmark.seal.fill",
                message: "Every leftover file on this Mac belongs to an installed app.",
                tint: Color(red: 0.40, green: 0.75, blue: 0.50)
            )
            .frame(minHeight: 260)
        } else {
            VStack(spacing: 14) {
                ForEach(state.orphans) { group in
                    OrphanGroupCard(group: group)
                }
            }
        }
    }
}

private struct OrphanGroupCard: View {
    let group: OrphanDetector.OrphanGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                TintedIcon(systemName: "questionmark.folder.fill", tint: Theme.accent, size: 26)
                Text(group.id)
                    .font(.callout.weight(.semibold))
                    .textSelection(.enabled)
                Spacer()
                Text("\(group.files.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: group.totalBytes, countStyle: .file))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().overlay(Theme.hairline)

            VStack(spacing: 0) {
                ForEach(Array(group.files.enumerated()), id: \.offset) { idx, file in
                    OrphanRow(file: file)
                    if idx < group.files.count - 1 {
                        Divider().overlay(Theme.hairline).padding(.leading, 14)
                    }
                }
            }
        }
        .cardBackground()
    }
}

private struct OrphanRow: View {
    let file: AssociatedFile

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent).font(.callout.weight(.medium))
                Text(file.url.deletingLastPathComponent().path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
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
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
        }
    }
}
