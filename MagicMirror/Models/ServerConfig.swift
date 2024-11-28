import Foundation
import SwiftData

@Model
class ServerConfig {
    var addr: String
    var createdAt: Date

    var serverAddress: ServerAddr {
        .hostPort(self.addr)
    }

    // TODO - server-specific config here

    init(addr: String) {
        self.addr = addr
        self.createdAt = .now
    }
}
