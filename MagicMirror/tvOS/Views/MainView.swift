import SwiftUI

enum Tabs: Equatable, Hashable, Identifiable {
    case browse
    case servers
    case settings

    var id: Self { self }
}

struct MainView: View {
    @State private var selection: Tabs = .browse
    @State private var selectedServer: Server? = Server(addr: "baldanders.tail2cb10.ts.net:9599")

    var body: some View {
        TabView(selection: $selection) {
            Tab("Launch Application", systemImage: "play.tv", value: Tabs.browse) {
                if let selectedServer {
                    ServerBrowser(server: selectedServer)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .onAppear {
                            Task {
                                await selectedServer.reloadSessionsAndApps()
                            }
                        }
                } else {
                    Sorry(
                        systemImage: "server.rack", title: "No Server Selected",
                        subtitle: "Configure a server to get started"
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }

            TabSection("Configuration") {
                Tab("Choose Server", systemImage: "server.rack", value: Tabs.servers) {
                    Text("Put a MusicView here")
                }

                Tab("Connection Settings", systemImage: "wrench.adjustable", value: Tabs.settings) {
                    Text("Put a MusicView here")
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    MainView()
}
