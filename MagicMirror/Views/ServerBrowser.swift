import MMClientCommon
import SwiftUI
import os

private enum Selection: Equatable, Hashable {
    case session(UInt64)
    case app(String)
    case folder(String)
}

struct ServerBrowser: View {
    let server: Server

    @State private var selection: Selection?
    @State private var folderNavigation: [AppFolder] = []

    @Environment(\.configSheetPresentation) var configSheetPresentation

    var body: some View {
        NavigationStack(path: $folderNavigation) {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                    if showSessions {
                        Section(
                            header: sectionHeader(
                                title: "Running Sessions", systemImage: "play.circle.fill",
                                accent: true
                            )
                        ) {
                            sessionList
                        }
                    }

                    Section(
                        header: sectionHeader(
                            title: "Applications", systemImage: "play.circle")
                    ) {
                        appList()
                    }
                }
                .padding(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            }
            .navigationTitle(server.addr)
            .focusedSceneValue(\.server, server)
            .navigationDestination(for: AppFolder.self) { folder in
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                        appList(for: folder)
                    }
                }
                .navigationTitle(folder.name)
                .focusedSceneValue(\.server, server)
            }
        }
    }

    private var sessionList: some View {
        ForEach(server.sessionsWithMatchingApp, id: \.0.id) {
            (session, app) in

            sessionCard(session: session, app: app)
                .padding()
                .contextMenu {
                    Button {
                        configSheetPresentation.presentLaunchConfigurationSheet(
                            for: LaunchTarget(server: server, application: app, session: session))
                    } label: {
                        Label("Connect...", systemImage: "play.fill")
                    }
                    Button {
                        //                    self.operationInProgress = true
                        Task {
                            try? await server.endSession(sessionID: session.id)
                            await server.reloadSessions()
                        }
                    } label: {
                        Label("End Session", systemImage: "play.fill")
                    }
                }
        }
    }

    private func sessionCard(session: Session, app: Application) -> AppCard<Selection?> {
        AppCard(
            name: app.displayName,
            imageURL: server.headerImageURL(for: app),
            systemIcon: "play.display",
            primaryColor: Color.accentColor,
            selection: $selection,
            tag: .session(session.id)
        ) {
            AttachmentWindowController.main.attach(
                server: server,
                session: session,
                config: LaunchSettings.shared.launchConfiguration(for: server))
        }
    }

    @ViewBuilder
    private func appList(for folder: AppFolder? = nil) -> some View {
        let folder = folder ?? server.rootFolder

        ForEach(folder.folderChildren.values) { folder in
            folderCard(folder: folder)
                .padding()
        }

        ForEach(folder.appChildren.values) { app in
            appCard(app: app)
                .padding()
                .contextMenu {
                    Button {
                        configSheetPresentation.presentLaunchConfigurationSheet(
                            for:
                                LaunchTarget(server: server, application: app, session: nil))
                    } label: {
                        Label("Launch...", systemImage: "play.fill")
                    }
                }
        }
    }

    private func folderCard(folder: AppFolder) -> AppCard<Selection?> {
        AppCard(
            name: folder.name,
            systemIcon: "folder.fill",
            selection: $selection,
            tag: .folder(folder.id)
        ) {
            self.folderNavigation.append(folder)
        }
    }

    private func appCard(app: Application) -> AppCard<Selection?> {
        AppCard(
            name: app.displayName,
            imageURL: server.headerImageURL(for: app),
            systemIcon: "display",
            selection: $selection,
            tag: .app(app.id)
        ) {
            AttachmentWindowController.main.launch(
                server: server, applicationID: app.id,
                config: LaunchSettings.shared.launchConfiguration(for: server))
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

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 160),
                alignment: .center
            )
        ]
    }
}
