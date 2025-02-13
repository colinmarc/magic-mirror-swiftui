import MMClientCommon
import SwiftUI

struct AppCard: View {
    let name: String
    let imageURL: URL?
    let systemIcon: String
    let color: Color

    let action: () -> Void

    init(
        name: String,
        imageURL: URL? = nil,
        systemIcon: String,
        color: Color,
        action: @escaping () -> Void = {}
    ) {
        self.name = name
        self.imageURL = imageURL
        self.systemIcon = systemIcon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            appImage
                .hoverEffect(.highlight)
            Text(name).lineLimit(1)
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder private var appImage: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable().aspectRatio(contentMode: .fit)

                } else if phase.error != nil {
                    placeholderImage
                } else {
                    progressView
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(color.gradient)
                .saturation(0.8)
                .aspectRatio(1.6, contentMode: .fill)

            Image(systemName: systemIcon)
                .resizable()
                .padding()
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.secondary, Color.secondary, Color.clear)
                .aspectRatio(contentMode: .fit)
        }
    }

    private var progressView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(color.gradient)
                .saturation(0.8)
                .aspectRatio(1.6, contentMode: .fill)

            ProgressView()
        }
    }
}
