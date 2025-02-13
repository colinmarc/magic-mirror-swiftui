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
                    ServerLoader(server: server) {
                        ServerBrowser(server: server)
                    }
                    .focusedSceneValue(\.server, server)
                } else {
                    Sorry(
                        systemImage: "server.rack", title: "No Server Selected",
                        subtitle: "Choose a server on the left to see available apps and sessions.")
                }
            }
        )
        .toolbar(removing: .sidebarToggle)
    }
}

#Preview {
    MainView()
}
