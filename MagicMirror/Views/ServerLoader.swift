import MMClientCommon
import SwiftUI

struct ServerLoader<Content: View>: View {
    let server: Server
    let content: () -> Content

    var body: some View {
        if let error = server.errorStatus {
            Sorry(for: error)
        } else if !server.apps.isEmpty {
            content()
        } else {
            ProgressView()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
