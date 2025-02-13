import SwiftUI

struct Sorry: View {
    let systemImage: String
    let title: String
    let subtitle: String

    init(systemImage: String, title: String, subtitle: String) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    init(for error: some Error, systemImage: String = "bolt.horizontal.circle") {
        self.init(
            systemImage: systemImage, title: "An Error Occurred",
            subtitle: error.localizedDescription)
    }

    var body: some View {
        ContentUnavailableView(
            title, systemImage: "bolt.horizontal.circle",
            description: Text(
                subtitle
            )
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(maxHeight: .infinity, alignment: .center)
    }
}
