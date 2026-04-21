import AppKit
import SwiftUI

struct ConfirmUninstallSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let app: InstalledApp

    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 0) {
            hero
            Divider().overlay(Theme.hairline)
            fileList
            Divider().overlay(Theme.hairline)
            footer
        }
        .frame(width: 540, height: 520)
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .top, spacing: 16) {
            AppIconView(url: app.url)
                .frame(width: 56, height: 56)
                .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Remove \(app.name)?")
                    .font(.title3.weight(.semibold))
                Text("Everything below will be moved to the Trash. You can restore from there if you change your mind.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
    }

    // MARK: - File list

    private var fileList: some View {
        List {
            SwiftUI.Section {
                row(
                    path: app.url.path,
                    size: app.sizeBytes,
                    admin: false,
                    tint: Theme.accent
                )
            } header: {
                listHeader("App bundle", count: 1)
            }

            if !state.selectedLeftovers.isEmpty {
                SwiftUI.Section {
                    ForEach(state.selectedLeftovers) { file in
                        row(
                            path: file.url.path,
                            size: file.sizeBytes,
                            admin: false,
                            tint: Theme.tint(for: file.kind)
                        )
                    }
                } header: {
                    listHeader("Related files", count: state.selectedLeftovers.count)
                }
            }

            let admin = state.leftovers.filter(\.requiresAdmin)
            if !admin.isEmpty {
                SwiftUI.Section {
                    ForEach(admin) { file in
                        row(
                            path: file.url.path,
                            size: file.sizeBytes,
                            admin: true,
                            tint: .orange
                        )
                    }
                } header: {
                    listHeader("Requires admin — skipped", count: admin.count)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private func listHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("·").foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func row(path: String, size: Int64?, admin: Bool, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint.opacity(0.85))
                .frame(width: 8, height: 8)
            Text(path)
                .font(.caption.monospaced())
                .foregroundStyle(admin ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let size {
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Total to reclaim")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(totalFormatted)
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            Spacer()
            Button("Cancel") {
                state.cancelUninstall()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.large)
            .disabled(isSubmitting)

            Button(role: .destructive) {
                isSubmitting = true
                Task {
                    await state.confirmUninstall()
                    isSubmitting = false
                    dismiss()
                }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 110)
                } else {
                    Label("Move to Trash", systemImage: "trash.fill")
                        .font(.callout.weight(.semibold))
                        .frame(minWidth: 110)
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var totalFormatted: String {
        let total = (app.sizeBytes ?? 0) + state.selectedLeftovers.reduce(0) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
}
