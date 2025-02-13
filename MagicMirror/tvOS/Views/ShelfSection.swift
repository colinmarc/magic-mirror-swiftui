import SwiftUI

struct ShelfSection<Data, ID, Content>: View
where Content: View, Data: RandomAccessCollection, ID: Hashable {
    private let title: String
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let content: (Data.Element) -> Content
    private let seeAllAction: (() -> Void)?

    init(
        _ title: String,
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        content: @escaping (Data.Element) -> Content,
        seeAllAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.data = data
        self.id = id
        self.content = content
        self.seeAllAction = seeAllAction
    }

    init(
        _ title: String,
        _ data: Data,
        content: @escaping (Data.Element) -> Content,
        seeAllAction: (() -> Void)? = nil
    ) where ID == Data.Element.ID, Data.Element: Identifiable {
        self.title = title
        self.data = data
        self.id = \.id
        self.content = content
        self.seeAllAction = seeAllAction
    }

    var body: some View {
        Section(self.title) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 40) {
                    if let seeAllAction {
                        Button(action: seeAllAction) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(.gray.gradient)
                                    .saturation(0.8)
                                    .aspectRatio(1.6, contentMode: .fill)

                                Image(systemName: "ellipsis")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .containerRelativeFrame(.vertical) { length, _ in length * 0.08
                                    }
                                    .foregroundStyle(Color.primary)
                            }
                            .hoverEffect(.highlight)

                            Text("See All")
                        }
                        .frame(maxWidth: 300)
                        .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                    }

                    ForEach(data, id: self.id) { d in
                        content(d)
                            .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                    }
                }
            }
            .scrollClipDisabled()
            .buttonStyle(.borderless)
            .padding()
            //            .containerRelativeFrame(.vertical, count: 4, spacing: 40)
        }
    }
}
