import MMClientCommon
import OSLog
import SwiftData
import SwiftUI

@main
struct MagicMirrorApp: App {
    private let logger = LogDelegate()

    @Bindable var configPresentation = ConfigSheetPresentation()

    init() {
        MMClientCommon.setLogger(logger: logger)

        #if DEBUG
            MMClientCommon.setLogLevel(level: .debug)
        #else
            MMClientCommon.setLogLevel(level: .info)
        #endif

        if URLProtocol.registerClass(MMImageURLProtocol.self) {
            Logger.general.info("installed MMImageUrlProtocol")
        } else {
            Logger.general.error("failed to install MMImageUrlProtocol")
        }
    }

    var body: some Scene {
        Window("Magic Mirror", id: "Browser") {
            MainView()
                .environment(\.configSheetPresentation, configPresentation)
                .sheet(
                    item: self.$configPresentation.launchConfigurationTarget,
                    onDismiss: self.configPresentation.onDismiss
                ) { target in
                    LaunchConfigSheet(for: target)
                        .scenePadding()
                        .frame(minWidth: 400)
                }
        }
        .modelContainer(for: [ServerConfig.self])
        .commands {
            ServerCommands()
            AttachmentCommands()
        }
    }
}
