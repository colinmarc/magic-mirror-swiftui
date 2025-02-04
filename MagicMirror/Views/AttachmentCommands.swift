import SwiftUI

struct AttachmentCommands: Commands {
    var body: some Commands {
        CommandMenu("Session") {
            reattach
            dismiss
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

    var dismiss: some View {
        Button {
            AttachmentWindowController.main.dismiss()
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
