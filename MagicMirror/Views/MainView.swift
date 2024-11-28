import MMClientCommon
import SwiftData
import SwiftUI

struct MainView: View {

    @State private var selectedServer: ServerAddr?

    var body: some View {
        NavigationSplitView(
            sidebar: {
                ServerListSidebar(selection: $selectedServer)
            },
            detail: {
                if let conf = selectedServer {
                    let server = ServerManager.shared.client(for: conf)
                    ServerLoader(server: server)
                } else {
                    ContentUnavailableView(
                        "No Server Selected", systemImage: "server.rack",
                        description: Text(
                            "Choose a server on the left to see available apps and sessions."
                        ))
                }
            }
        )
        .toolbar(removing: .sidebarToggle)
    }
}

#Preview {
    MainView()
}
