import Collections
import SwiftUI

@MainActor
class ServerManager {
    static let shared = ServerManager()

    init() {
        self.clientCache = [:]
    }

    //    func savedServers(modelContext: ModelContext) -> [Server] {
    //        let descriptor = FetchDescriptor<ServerConfig>(
    //            sortBy: [
    //                .init(\.createdAt)
    //            ]
    //        )
    //
    //        if let res = try? modelContext.fetch(descriptor) {
    //            return res.map { self.get($0.addr) }
    //        } else {
    //            return []
    //        }
    //    }

    private var clientCache: [String: Server]

    func client(for config: ServerConfig) -> Server {
        self.client(for: config.addr)
    }

    func client(for addr: String) -> Server {
        if let server = clientCache[addr] {
            return server
        } else {
            let s = Server(addr: addr)
            clientCache[addr] = s
            return s
        }
    }
}
