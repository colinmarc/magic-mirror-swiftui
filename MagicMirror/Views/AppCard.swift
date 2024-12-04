import MMClientCommon
import SwiftUI

struct AppCard<Selection: Hashable>: View {
    let name: String
    let imageURL: URL?
    let systemIcon: String
    let primaryColor: Color

    @Binding var selection: Selection
    let tag: Selection

    let action: () -> Void

    init(
        name: String,
        imageURL: URL? = nil,
        systemIcon: String,
        primaryColor: Color = .secondary,
        selection: Binding<Selection>,
        tag: Selection,
        action: @escaping () -> Void = {}
    ) {
        self.name = name
        self.imageURL = imageURL
        self.systemIcon = systemIcon
        self.primaryColor = primaryColor
        self._selection = selection
        self.tag = tag
        self.action = action
    }

    private var selected: Bool {
        selection == tag
    }

    var body: some View {
        VStack {
            appImage
                .frame(width: 160, height: 90)

            //            if operationInProgress {
            //                ZStack {
            //                    image.opacity(0.4)
            //                    ProgressView()
            //                }
            //            } else {
            //                image
            //            }

            let text = Text(name)
                .lineLimit(1)
                .font(.footnote)
            if selected {
                text.background {
                    RoundedRectangle(cornerRadius: 1.0)
                        .inset(by: -4.0).fill(Color.accentColor)
                }
            } else {
                text
            }
        }
        .padding()
        .frame(width: 160, height: 120)
        // Make anywhere inside the border clickable.
        .contentShape(Rectangle())
        .highPriorityGesture(TapGesture(count: 2).onEnded(action))
        .simultaneousGesture(
            _ButtonGesture(
                action: {},
                pressing: { pressing in
                    if pressing {
                        selection = tag
                    }
                })
        )
    }

    @ViewBuilder private var appImage: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                        .padding([.vertical], 10)
                        .shadow(
                            color: selected ? .accentColor : .init(red: 0.3, green: 0.3, blue: 0.3),
                            radius: 10)
                } else if phase.error != nil {
                    placeholderImage
                } else {
                    ProgressView()
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        return Image(systemName: systemIcon)
            .resizable()
            .symbolRenderingMode(.palette)
            .foregroundStyle(primaryColor, Color.secondary, Color.clear)
            .aspectRatio(contentMode: .fit)
            .padding([.vertical], 10)
    }
}

extension MMClientCommon.Application {
    var headerImageAvailable: Bool {
        self.imagesAvailable.contains(.header)
    }

    var displayName: String {
        if self.description != "" {
            return self.description
        } else {
            return self.id
        }
    }
}

#Preview {
    @Previewable @State var selection: Int = 0
    let server = Server(addr: "baldanders:9599")
    let apps = [
        Application(
            id: "foo-bar",
            description: "Foo Bar",
            folder: [],
            imagesAvailable: []
        ),
        Application(
            id: "steam-gamepadui",
            description: "Steam",
            folder: [],
            imagesAvailable: [.header]
        ),
        Application(
            id: "book-of-hours-1028310",
            description: "Foo Bar Baz This is Too Long Way Too Long",
            folder: [],
            imagesAvailable: [.header]
        ),
    ]

    let targets = [
        LaunchTarget(
            server: server,
            application: apps[0],
            session: nil
        ),
        LaunchTarget(
            server: server,
            application: apps[0],
            session: Session(
                id: 123, applicationId: "foo-bar", start: Date(),
                displayParams: DisplayParams(width: 100, height: 200, framerate: 60, uiScale: .one))
        ),
        LaunchTarget(
            server: server,
            application: apps[1],
            session: nil
        ),
        LaunchTarget(
            server: server,
            application: apps[1],
            session: Session(
                id: 123, applicationId: "steam-gamepadui", start: Date(),
                displayParams: DisplayParams(width: 100, height: 200, framerate: 60, uiScale: .one))
        ),
    ]

    HStack {
        VStack {
            AppCard(
                name: apps[0].displayName, systemIcon: "play.display", selection: $selection,
                tag: 0)
            AppCard(
                name: apps[0].displayName, systemIcon: "play.display",
                primaryColor: Color.accentColor, selection: $selection, tag: 1)
        }
        .padding()
        VStack {
            AppCard(
                name: apps[1].displayName, systemIcon: "play.display", selection: $selection,
                tag: 2)
            AppCard(
                name: apps[1].displayName, systemIcon: "play.display",
                primaryColor: Color.accentColor, selection: $selection, tag: 3)
        }.padding()
        VStack {
            AppCard(
                name: apps[1].displayName, imageURL: server.headerImageURL(for: apps[1]),
                systemIcon: "play.display", selection: $selection, tag: 4)
            AppCard(
                name: apps[2].displayName, imageURL: server.headerImageURL(for: apps[2]),
                systemIcon: "folder", selection: $selection,
                tag: 5)
        }
        .padding()
    }
}
