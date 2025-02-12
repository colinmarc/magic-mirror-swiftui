import MMClientCommon
import OSLog

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
