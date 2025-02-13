import SwiftUI

struct ServerTitle: View {
    let server: Server

    init(for server: Server) {
        self.server = server
    }

    var body: some View {
        HStack(alignment: .top, spacing: 30) {
            Image(systemName: "network")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.blue.gradient)
            VStack(alignment: .leading) {
                Text(server.addr.displayName).font(.title2)
                //                Text(server.addr.ipAddress)
                Text("ping: \(serverPingMs)").foregroundStyle(.secondary)
            }
        }
    }

    private var serverPingMs: String {
        if let d = server.currentPing {
            d.formatted(
                .units(
                    allowed: [.milliseconds],
                    width: .condensedAbbreviated))
        } else {
            "-"
        }
    }
}

#Preview {
    ZStack(alignment: .topTrailing) {
        ServerTitle(for: Server(addr: "baldanders.tail2cb10.ts.net:9599"))
    }
}
