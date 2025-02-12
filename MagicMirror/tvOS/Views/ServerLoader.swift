import MMClientCommon
import SwiftUI

struct ServerLoader: View {
    let server: Server

    var body: some View {
        if let error = server.errorStatus {
            ContentUnavailableView(
                "An Error Occurred", systemImage: "bolt.horizontal.circle",
                description: Text(
                    error.localizedDescription
                ))
        } else if !server.apps.isEmpty {
            Text("no servers?")
        } else {
            ProgressView()
                .foregroundStyle(.secondary)
        }
    }
}
