import MMClientCommon
import OSLog
import SwiftData
import SwiftUI

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let attachment = Logger(subsystem: subsystem, category: "attachment")
    static let client = Logger(subsystem: subsystem, category: "client")
    static let renderer = Logger(subsystem: subsystem, category: "renderer")
    static let general = Logger(subsystem: subsystem, category: "general")
    fileprivate static let clientCommon = Logger(subsystem: subsystem, category: "client-common")
}

class LogDelegate: MMClientCommon.LogDelegate {
    func log(level: LogLevel, target: String, msg: String) {
        if !target.starts(with: "mm") {
            return
        }

        let lvl: OSLogType
        switch level {
        case .trace:
            return
        case .debug:
            lvl = .debug
        case .info:
            lvl = .info
        case .warn, .error:
            lvl = .error
        default:
            return
        }

        Logger.clientCommon.log(level: lvl, "\(target, privacy: .public): \(msg, privacy: .public)")
    }
}

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

@Observable
class ConfigSheetPresentation {
    var launchConfigurationTarget: LaunchTarget? = nil

    var addServerSheetIsPresented = false

    func presentLaunchConfigurationSheet(for target: LaunchTarget) {
        self.launchConfigurationTarget = target
    }

    func presentAddServerSheet() {
        self.addServerSheetIsPresented = true
    }

    func onDismiss() {
        self.launchConfigurationTarget = nil
        self.addServerSheetIsPresented = false
    }
}

extension EnvironmentValues {
    @Entry var configSheetPresentation = ConfigSheetPresentation()
}
