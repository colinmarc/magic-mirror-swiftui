import Collections
import Network
import SwiftUI

@MainActor @Observable
class ServerManager {
    static let shared = ServerManager()

    private var mdnsBrowser: NWBrowser
    var localServers: [ServerAddr]

    init() {
        self.clientCache = [:]
        self.mdnsBrowser = NWBrowser(
            for: .bonjour(type: "_magic-mirror._udp.", domain: nil), using: .udp)

        self.localServers = []
        self.mdnsBrowser.browseResultsChangedHandler = { (results, _) in
            DispatchQueue.main.async {
                self.localServers = results.map { ServerAddr.mdns($0.endpoint) }
            }
        }

        self.mdnsBrowser.start(queue: DispatchQueue.main)
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

    private var clientCache: [ServerAddr: Server]

    func client(for config: ServerConfig) -> Server {
        self.client(for: .hostPort(config.addr))
    }

    func client(for addr: ServerAddr) -> Server {
        if let server = clientCache[addr] {
            return server
        } else {
            let s = Server(addr: addr)
            clientCache[addr] = s
            return s
        }
    }
}
