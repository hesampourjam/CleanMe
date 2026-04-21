import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var permissions: PermissionChecker

    var body: some View {
        Group {
            if permissions.hasFullDiskAccess {
                mainLayout
            } else {
                FDARequiredView()
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { state.lastError != nil },
                set: { if !$0 { state.lastError = nil } }
            ),
            presenting: state.lastError
        ) { _ in
            Button("OK", role: .cancel) { state.lastError = nil }
        } message: { message in
            Text(message)
        }
    }

    /// Applications needs three columns (sidebar | app list | detail).
    /// Other sections need two (sidebar | content).
    @ViewBuilder private var mainLayout: some View {
        switch state.selectedSection {
        case .applications:
            threeColumn
        case .orphans, .extensions, .history, .about:
            twoColumn
        }
    }

    private var threeColumn: some View {
        NavigationSplitView {
            sidebar
        } content: {
            AppListView()
                .navigationSplitViewColumnWidth(min: 325, ideal: 375, max: 475)
        } detail: {
            Group {
                if let app = state.selectedApp {
                    AppDetailView(app: app)
                } else {
                    EmptyStateView(
                        "Select an application",
                        systemImage: "app.dashed",
                        message: "Pick an app from the list to see what would be removed."
                    )
                }
            }
            .frame(minWidth: 440)
        }
        .sheet(item: Binding(
            get: { state.pendingUninstall },
            set: { state.pendingUninstall = $0 }
        )) { app in
            ConfirmUninstallSheet(app: app)
                .environmentObject(state)
        }
    }

    private var twoColumn: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailForCurrentSection
                .frame(minWidth: 640)
        }
    }

    private var sidebar: some View {
        List(selection: $state.selectedSection) {
            SidebarRow(title: "Applications",   symbol: "square.grid.2x2.fill",        tag: .applications, selected: state.selectedSection)
            SidebarRow(title: "Orphaned Files", symbol: "questionmark.folder.fill",    tag: .orphans,      selected: state.selectedSection)
            SidebarRow(title: "Extensions",     symbol: "puzzlepiece.extension.fill",  tag: .extensions,   selected: state.selectedSection)

            SwiftUI.Section {
                SidebarRow(title: "History", symbol: "clock.arrow.circlepath", tag: .history, selected: state.selectedSection)
                SidebarRow(title: "About",   symbol: "sparkles",               tag: .about,   selected: state.selectedSection)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("CleanMe")
        .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 270)
    }

    @ViewBuilder private var detailForCurrentSection: some View {
        switch state.selectedSection {
        case .applications:
            // Unreachable — handled by threeColumn — but switch must be exhaustive.
            EmptyView()
        case .orphans:
            OrphansView()
        case .extensions:
            ExtensionsView()
        case .history:
            HistoryView()
        case .about:
            AboutView()
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let symbol: String
    let tag: AppState.NavItem
    let selected: AppState.NavItem

    var body: some View {
        let isSelected = (tag == selected)
        Label {
            Text(title).font(.callout.weight(.medium))
        } icon: {
            Image(systemName: symbol)
                .font(.callout)
                // Tint the icon blue when the row is unselected. macOS paints the
                // whole label white on the selected row; overriding there would fight
                // the system and make selection unreadable.
                .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.accent))
                .frame(width: 22, alignment: .center)
        }
        .padding(.vertical, 2)
        .tag(tag)
    }
}
