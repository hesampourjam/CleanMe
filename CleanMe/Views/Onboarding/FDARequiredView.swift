import SwiftUI

struct FDARequiredView: View {
    @EnvironmentObject private var permissions: PermissionChecker

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            TintedIcon(systemName: "lock.shield.fill", tint: Theme.accent, size: 96)

            VStack(spacing: 8) {
                Text("One last step")
                    .font(.system(size: 28, weight: .bold))
                Text("CleanMe needs Full Disk Access to find leftover files in your Library.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            VStack(alignment: .leading, spacing: 12) {
                step(1, "Open System Settings → Privacy & Security → Full Disk Access.")
                step(2, "Turn on the switch next to CleanMe.")
                step(3, "Come back and tap ", link: "I've granted access")
            }
            .padding(20)
            .frame(maxWidth: 460, alignment: .leading)
            .cardBackground()

            HStack(spacing: 10) {
                Button {
                    permissions.openFullDiskAccessSettings()
                } label: {
                    Label("Open Settings", systemImage: "arrow.up.right.square.fill")
                        .font(.callout.weight(.semibold))
                        .frame(minWidth: 140)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button {
                    permissions.refresh()
                } label: {
                    Text("I've granted access")
                        .font(.callout.weight(.medium))
                        .frame(minWidth: 140)
                }
                .controlSize(.large)
            }

            Text("CleanMe never connects to the network. Your files stay on this Mac.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func step(_ n: Int, _ text: String, link: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Theme.accent.opacity(0.18), in: Circle())
                .foregroundStyle(Theme.accent)
            if let link {
                (Text(text) + Text(link).bold())
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
