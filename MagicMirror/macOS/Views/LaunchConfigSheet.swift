import MMClientCommon
import SwiftUI

struct LaunchConfigSheet: View {
    let configuring: LaunchTarget?

    @Environment(\.dismiss) var dismiss
    @StateObject var settings = LaunchSettings.shared
    @State var showDecoderWarning: Bool = false

    init(for configuring: LaunchTarget) {
        self.configuring = configuring
        self.showDecoderWarning = !LaunchSettings.shared.videoCodec.hasHardwareSupport
    }

    var launchButtonText: String {
        if let target = self.configuring {
            if target.session != nil {
                "Connect to \"\(target.application.displayName)\""
            } else {
                "Launch \"\(target.application.displayName)\""
            }
        } else {
            "Launch"
        }
    }

    var body: some View {
        VStack {
            Form {
                remoteDisplaySection
                streamSection
            }
            .formStyle(.grouped)
            .padding(.bottom, 10)

            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: submit) {
                    Text(launchButtonText)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    @ViewBuilder var remoteDisplaySection: some View {
        Section {
            Picker("Resolution", selection: $settings.remoteDisplayResolutionMode) {
                Text("Automatic")
                    .tag(RemoteDisplayResolutionMode.auto)

                Picker(
                    "Automatic width, fixed height", selection: $settings.remoteDisplayFixedHeight
                ) {
                    ForEach(RemoteDisplayFixedHeight.allCases, id: \.self) { fixedHeight in
                        Text(fixedHeight.description)
                    }
                }
                .pickerStyle(.menu)
                .disabled(settings.remoteDisplayResolutionMode != .fixedHeight)
                .tag(RemoteDisplayResolutionMode.fixedHeight)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Dimensions")
                    TextField(
                        value: $settings.remoteDisplayCustomWidth,
                        format: .number.rounded(rule: .up, increment: 2).grouping(.never)
                    ) { Text("Width:") }
                    TextField(
                        value: $settings.remoteDisplayCustomHeight,
                        format: .number.rounded(rule: .up, increment: 2).grouping(.never)
                    ) { Text("Height:") }
                }
                .disabled(settings.remoteDisplayResolutionMode != .customDimensions)
                .tag(RemoteDisplayResolutionMode.customDimensions)
            }
            .pickerStyle(.inline)

            Picker("Framerate", selection: $settings.remoteDisplayFramerate) {
                ForEach(RemoteDisplayFramerate.allCases, id: \.self) { fps in
                    Text(String(fps.rawValue))
                }
            }

            Toggle(isOn: $settings.force1xScale) {
                Text("Disable UI Scaling")
            }
        } header: {
            Label("Remote Display", systemImage: "display.2")
        } footer: {
            Text(
                "Automatic mode continually updates the remote display to match the local window's resolution."
            ).font(.footnote).foregroundStyle(.secondary)
        }
    }

    var streamSection: some View {
        Section {
            Picker("Local Window Mode", selection: $settings.localDisplayMode) {
                ForEach(LocalDisplayMode.allCases) { displayMode in
                    Text(displayMode.rawValue.capitalized)
                }
            }
            .pickerStyle(.segmented)

            Picker("Video Codec", selection: $settings.videoCodec) {
                ForEach(VideoCompressionCodec.allCases) { codec in
                    Text(codec.rawValue.uppercased())
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.videoCodec) { _, codec in
                withAnimation {
                    self.showDecoderWarning = !codec.hasHardwareSupport
                }
            }

            LabeledContent {
                VStack {
                    Slider(value: $settings.qualityPreset, in: 1...10, step: 1)
                    Text("Preset: \(Int(settings.qualityPreset))/10").font(.footnote)
                    // TODO
                    //Text("Estimated bitrate: 100mbps")
                }
            } label: {
                Text("Quality Preset")
            }
        } header: {
            Label("Stream Options", systemImage: "play.circle")
        } footer: {
            if showDecoderWarning {
                HStack {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.yellow)
                        .frame(height: 10)
                    Text("No hardware decoder found for the selected video codec!")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    func submit() {
        dismiss()

        guard let target = self.configuring else {
            return
        }

        let launchConfig = self.settings.launchConfiguration(for: target.server)
        if let session = self.configuring?.session {
            AttachmentWindowController.main.attach(
                server: target.server, session: session, config: launchConfig)
        } else {
            AttachmentWindowController.main.launch(
                server: target.server, applicationID: target.application.id, config: launchConfig)
        }
    }
}

#Preview {
    LaunchConfigSheet(
        for: LaunchTarget(
            server: Server(addr: "baldanders:9599"),
            application: Application(
                id: "steam", description: "Steam", folder: [], imagesAvailable: []), session: nil)
    )
    .frame(width: 400)
    .scenePadding()
}
