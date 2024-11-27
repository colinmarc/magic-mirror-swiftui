import SwiftUI

struct AttachmentOverlay: View {
    var presentation: AttachmentPresentation

    var body: some View {
        ZStack {
            Rectangle().fill(.clear).scaledToFill()

            message
                .frame(minWidth: 150, idealWidth: 250, maxWidth: 500)
        }
    }

    @ViewBuilder var message: some View {
        switch presentation.status {
        case .liveOperation(let msg), .operation(let msg):
            HStack {
                ProgressView().padding([.trailing])
                Text(msg)
            }
            .padding()
        case .errored(let err, let ce):
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.red)
                        .frame(width: 45, height: 45)
                        .padding([.trailing])
                    Text(err.localizedDescription)
                }.padding()
                if let ce = ce {
                    Text(ce.localizedDescription)
                        .italic().font(.footnote).foregroundStyle(Color.secondary)
                }
            }
        case .ended:
            HStack {
                Image(systemName: "sun.horizon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .padding([.trailing])
                Text("Attachment ended.")
            }
        case .none, .connected:
            EmptyView()
        }
    }
}
