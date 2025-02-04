import SwiftUI

struct LoadingSpinner: View {
    let strokeWidth: Double? = nil
    var speed: Double? = nil
    @State var rotation: Double = 0

    var spin: Animation {
        Animation.linear(duration: 2.0 / (speed ?? 1.0)).repeatForever(autoreverses: false)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    .secondary, style: StrokeStyle(lineWidth: strokeWidth ?? 1.2, lineCap: .round))
            Circle()
                .trim(from: 0.0, to: 0.25)
                .rotation(.degrees(360 * rotation))
                .stroke(.primary, style: StrokeStyle(lineWidth: strokeWidth ?? 1, lineCap: .round))
                .animation(spin, value: rotation)
        }
        .onAppear {
            rotation = 1.0
        }
    }
}

#Preview {
    HStack {
        LoadingSpinner().frame(width: 20, height: 20).padding()
        LoadingSpinner(speed: 2.0).frame(width: 20, height: 20).foregroundStyle(.blue).padding()
        LoadingSpinner(speed: 0.5).frame(width: 20, height: 20).foregroundStyle(.red)
            .padding()
    }
}
