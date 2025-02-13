import MMClientCommon
import SwiftUI
import os

enum Destination: Equatable, Hashable {
    case sessions
    case appFolder(AppFolder)
}

struct ServerBrowser: View {
    let server: Server

    @State private var navigationPath: [Destination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical) {
                VStack {
                    ServerTitle(for: server)
                        .containerRelativeFrame(.vertical) { length, _ in length * 0.2 }
                        .padding()

                    ServerLoader(server: server) {
                        VStack(alignment: .leading) {
                            if showSessions {
                                ShelfSection(
                                    "Running Sessions", server.sessionsWithMatchingApp, id: \.0.id
                                ) {
                                    (session, app) in

                                    sessionCard(session: session, app: app)
                                        .padding()
                                }
                                .frame(maxHeight: 260)
                            }

                            ShelfSection("Applications", server.rootFolder.appChildren.values) {
                                app in
                                appCard(app: app)
                                    .padding()
                            }
                            .frame(maxHeight: 260)

                            if showFolders {
                                ShelfSection(
                                    "Application Folders", server.rootFolder.folderChildren.values
                                ) {
                                    folder in
                                    folderCard(folder: folder)
                                        .padding()
                                } seeAllAction: {
                                    navigationPath = [.appFolder(server.rootFolder)]
                                }
                                .frame(maxHeight: 260)
                            }
                        }
                    }
                }
            }.scrollClipDisabled()
        }
        .navigationDestination(for: Destination.self) { dest in
            switch dest {
            case .sessions:
                fullSessionList
            case .appFolder(let folder):
                fullAppList(for: folder)
            }
        }
    }

    private var listColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 300),
                alignment: .center
            )
        ]
    }

    private var fullSessionList: some View {
        cardList("Running Sessions") {
            LazyVGrid(columns: listColumns) {
                ForEach(server.sessionsWithMatchingApp, id: \.0.id) { (session, app) in
                    sessionCard(session: session, app: app)
                        .containerRelativeFrame(.horizontal, count: 6, spacing: 120)
                        .padding()
                }
            }
        }
    }

    @ViewBuilder
    private func fullAppList(for folder: AppFolder) -> some View {
        cardList(folder.name) {
            ForEach(folder.folderChildren.values) { folder in
                folderCard(folder: folder)
                    .containerRelativeFrame(.horizontal, count: 6, spacing: 120)
                    .padding()
            }

            ForEach(folder.appChildren.values) { app in
                appCard(app: app)
                    .containerRelativeFrame(.horizontal, count: 6, spacing: 120)
                    .padding()
            }
        }
    }

    private func cardList<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack {
            Text(title).font(.title)
                .padding(.bottom, -20)

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], alignment: .center, spacing: 50
                ) {
                    content()
                }
                .padding()
                .padding(.top, 120)
            }
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [.black, .black, .black, .clear]),
                    startPoint: .center, endPoint: .top))
        }
    }

    private func sessionCard(session: Session, app: Application) -> AppCard {
        AppCard(
            name: app.displayName,
            imageURL: server.headerImageURL(for: app),
            systemIcon: "play.display",
            color: Color.green
        ) {
            // todo
        }
    }

    private func folderCard(folder: AppFolder) -> AppCard {
        AppCard(
            name: folder.name,
            systemIcon: "folder.fill",
            color: Color.gray
        ) {
            self.navigationPath.append(.appFolder(folder))
        }
    }

    private func appCard(app: Application) -> AppCard {
        AppCard(
            name: app.displayName,
            imageURL: server.headerImageURL(for: app),
            systemIcon: "display",
            color: Color.blue
        ) {
            // todo
        }
    }

    private func sectionHeader(title: String, systemImage: String, accent: Bool = false)
        -> some View
    {
        Label {
            Text(title).foregroundStyle(.foreground)
                .font(.title)
        } icon: {
            if accent {
                Image(systemName: systemImage)
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundStyle(Color.accentColor)
            } else {
                Image(systemName: systemImage)
                    .resizable()
                    .frame(width: 25, height: 25)
            }
        }
        .padding(.top, 20)
    }

    private var showSessions: Bool {
        server.sessions.count > 0
    }

    private var showFolders: Bool {
        server.rootFolder.folderChildren.count > 0
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 160),
                alignment: .center
            )
        ]
    }
}

#Preview {
    ServerBrowser(server: Server(addr: "baldanders.tail2cb10.ts.net:9599"))
}
