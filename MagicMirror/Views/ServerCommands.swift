import SwiftUI

struct ServerCommands: Commands {
    @FocusedValue(\.server) var focusedServer: Server?

    var body: some Commands {
        CommandMenu("Server") {
            Button {
                Task {
                    await focusedServer?.reloadSessionsAndApps(resetError: true)
                }
            } label: {
                Text("Refresh")
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(focusedServer == nil)
        }
    }
}
