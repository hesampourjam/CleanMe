import AppKit
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var state: AppState

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

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
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("History").font(.title.weight(.bold))
                Text("Everything you've removed. Items stay in the Trash until you empty it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !state.history.isEmpty {
                Button(role: .destructive) {
                    Task { await state.clearHistory() }
                } label: {
                    Label("Clear history", systemImage: "trash")
                        .font(.callout.weight(.medium))
                }
                .controlSize(.large)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if state.history.isEmpty {
            EmptyStateView(
                "No history yet",
                systemImage: "clock.arrow.circlepath",
                message: "Apps you remove will show up here.",
                tint: Theme.accent
            )
            .frame(minHeight: 280)
        } else {
            VStack(spacing: 12) {
                ForEach(state.history) { record in
                    HistoryCard(record: record)
                }
            }
        }
    }

    static func formatted(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

private struct HistoryCard: View {
    @EnvironmentObject private var state: AppState
    let record: UninstallRecord
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    TintedIcon(systemName: "trash.fill", tint: Theme.accent, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.appName).font(.callout.weight(.semibold))
                        Text(HistoryView.formatted(record.uninstalledAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: record.totalBytes, countStyle: .file))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().overlay(Theme.hairline)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(record.items, id: \.originalURL) { item in
                        HStack(spacing: 8) {
                            Text(item.originalURL.path)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if let trashed = item.trashedURL {
                                Button("Reveal in Trash") {
                                    NSWorkspace.shared.activateFileViewerSelecting([trashed])
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                        }
                    }
                    if !record.skippedAdminItems.isEmpty {
                        Text("\(record.skippedAdminItems.count) admin-only item(s) were skipped.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    HStack {
                        Spacer()
                        Button {
                            Task { await state.deleteHistory(id: record.id) }
                        } label: {
                            Label("Forget this entry", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help("Removes the record from history — files stay in the Trash.")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .transition(.opacity)
            }
        }
        .cardBackground()
    }
}
