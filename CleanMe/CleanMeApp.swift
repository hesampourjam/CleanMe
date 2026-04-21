import SwiftUI

@main
struct CleanMeApp: App {
    @StateObject private var state = AppState()
    @StateObject private var permissions = PermissionChecker()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(permissions)
                .frame(minWidth: 900, minHeight: 560)
                .task { await state.initialScan() }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("Scan for Apps") { Task { await state.rescan() } }
                    .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
