import MMClientCommon
import OSLog
import SwiftData
import SwiftUI

@main
struct MagicMirrorApp: App {
    private let logger = LogDelegate()

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
        WindowGroup {
            MainView()
                .modelContainer(for: [ServerConfig.self])
        }
    }
}
