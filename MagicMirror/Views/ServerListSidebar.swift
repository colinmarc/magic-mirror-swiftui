import SwiftData
import SwiftUI

struct ServerListSidebar: View {
    @Query(sort: \ServerConfig.createdAt) private var savedServers: [ServerConfig]

    @State private var showServerAddButton = false
    @Environment(\.configSheetPresentation) var configSheetPresentation

    @Binding var selection: ServerAddr?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var configPresentation = configSheetPresentation

        List(selection: $selection) {
            Section {
                HStack {
                    sidebarSectionHeader("Saved Servers")
                    Spacer()
                    Button {
                        configPresentation.presentAddServerSheet()
                    } label: {
                        Image(systemName: "plus.circle")
                    }.buttonStyle(.borderless)
                        .opacity(showServerAddButton ? 1 : 0)
                }

                ForEach(savedServers, id: \.self.serverAddress) { serverConfig in
                    serverLink(server: ServerManager.shared.client(for: serverConfig))
                        .contextMenu {
                            Button {
                                modelContext.delete(serverConfig)
                            } label: {
                                Text("Remove Server")
                            }
                        }
                }
            }

            Section {
                sidebarSectionHeader("Local Network")
                    .padding([.top], 20)

                ForEach(ServerManager.shared.localServers, id: \.self) {
                    serverLink(server: ServerManager.shared.client(for: $0))
                }
            }
        }
        .listStyle(.sidebar)
        .onHover { isHovered in
            showServerAddButton = isHovered
        }
        .sheet(
            isPresented: $configPresentation.addServerSheetIsPresented,
            onDismiss: configPresentation.onDismiss
        ) {
            AddServerSheet(updateSelectionOnSubmit: $selection)
                .scenePadding()
                .frame(minWidth: 400)
        }
    }

    @ViewBuilder func sidebarSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder func serverLink(server: Server) -> some View {
        HStack {
            Text(server.addr.displayName)
            Spacer()
            sidebarImage(for: server.connectionStatus)
        }
    }

    @ViewBuilder func sidebarImage(for status: LastStatus) -> some View {
        switch status {
        case .error, .disconnected:
            Image(systemName: "bolt.horizontal.circle")
                .foregroundStyle(.secondary)
        case .connecting:
            Image(systemName: "progress.indicator")
                .symbolEffect(.variableColor.iterative, options: .repeating)
        default:
            EmptyView()
        }
    }
}
