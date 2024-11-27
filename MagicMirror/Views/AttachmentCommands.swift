import SwiftUI

struct AttachmentCommands: Commands {
    var body: some Commands {
        CommandMenu("Session") {
            reattach
            detach
            releaseCursor
        }
    }

    var reattach: some View {
        Button {
            AttachmentWindowController.main.refresh()
        } label: {
            Text("Reconnect")
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(!AttachmentWindowController.main.status.isSome)
    }

    var detach: some View {
        Button {
            AttachmentWindowController.main.detach()
        } label: {
            Text("Disconnect")
        }
        .keyboardShortcut("d", modifiers: [.command])
        .disabled(!AttachmentWindowController.main.status.isSome)
    }

    var releaseCursor: some View {
        Button {
            AttachmentWindowController.main.releaseCursor()
        } label: {
            Text("Release Cursor")
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])
    }
}
