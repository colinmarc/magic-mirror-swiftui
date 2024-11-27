import SwiftUI
import VideoToolbox

enum LocalDisplayMode: String, Codable, CaseIterable, Hashable, Identifiable {
    case windowed
    case fullscreen

    var id: Self {
        return self
    }
}

enum RemoteDisplayFixedHeight: Int, Codable, CaseIterable, Hashable, Identifiable {
    case res480p = 480
    case res720p = 780
    case res1080p = 1080
    case res2160p = 2160

    var id: Self {
        return self
    }

    var description: String {
        switch self {
        case .res480p:
            "480p"
        case .res720p:
            "720p"
        case .res1080p:
            "1080p"
        case .res2160p:
            "2160p"
        }
    }

    func calculateWidth(for rect: CGSize) -> UInt32 {
        let fixed = Double(self.rawValue)
        let scaleFactor = fixed / rect.height
        return UInt32(
            CGSize(width: rect.width * scaleFactor, height: fixed).makeEven().width)
    }
}

enum RemoteDisplayResolutionMode: String, Codable, CaseIterable, Hashable, Identifiable {
    case auto
    case fixedHeight
    case customDimensions

    var id: Self {
        return self
    }
}

enum RemoteDisplayFramerate: Int, Codable, CaseIterable, Hashable, Identifiable {
    case fps30 = 30
    case fps60 = 60
    //    case fps120

    var id: Self {
        return self
    }
}

enum VideoCompressionCodec: String, Codable, CaseIterable, Hashable, Identifiable {
    case h264
    case h265
    case av1

    var id: Self {
        return self
    }

    var hasHardwareSupport: Bool {
        let val =
            switch self {
            case .h264:
                kCMVideoCodecType_H264
            case .h265:
                kCMVideoCodecType_HEVC
            case .av1:
                kCMVideoCodecType_AV1
            }

        return VTIsHardwareDecodeSupported(val)
    }
}

enum RemoteDisplayConfiguration {
    case auto
    case fixedHeight(RemoteDisplayFixedHeight)
    case customDimensions(UInt32, UInt32)
}

class LaunchSettings: ObservableObject {
    static let shared = LaunchSettings()

    @AppStorage("localDisplayMode") var localDisplayMode: LocalDisplayMode = .fullscreen

    @AppStorage("remoteDisplayResolutionMode") var remoteDisplayResolutionMode:
        RemoteDisplayResolutionMode = .auto
    @AppStorage("remoteDisplayFixedHeight") var remoteDisplayFixedHeight: RemoteDisplayFixedHeight =
        .res1080p
    @AppStorage("remoteDisplayCustomWidth") var remoteDisplayCustomWidth: Int = 1920
    @AppStorage("remoteDisplayCustomHeight") var remoteDisplayCustomHeight: Int = 1080
    @AppStorage("remoteDisplayFramerate") var remoteDisplayFramerate: RemoteDisplayFramerate =
        .fps60
    @AppStorage("remoteDisplayForce1xScale") var force1xScale: Bool = false

    @AppStorage("videoCodec") var videoCodec: VideoCompressionCodec = .h265
    @AppStorage("qualityPreset") var qualityPreset: Double = 6

    func launchConfiguration(for server: Server) -> LaunchConfiguration {
        let remoteDisplayConfig: RemoteDisplayConfiguration =
            switch self.remoteDisplayResolutionMode {
            case .auto:
                .auto
            case .fixedHeight:
                .fixedHeight(self.remoteDisplayFixedHeight)
            case .customDimensions:
                .customDimensions(
                    UInt32(self.remoteDisplayCustomWidth),
                    UInt32(self.remoteDisplayCustomHeight))
            }

        return LaunchConfiguration(
            localDisplayMode: self.localDisplayMode,
            remoteDisplayConfig: remoteDisplayConfig,
            remoteDisplayFramerate: self.remoteDisplayFramerate,
            forceRemoteScaleToBe1x: self.force1xScale,
            codec: self.videoCodec,
            preset: Int(self.qualityPreset))
    }
}

struct LaunchConfiguration {
    let localDisplayMode: LocalDisplayMode
    let remoteDisplayConfig: RemoteDisplayConfiguration
    let remoteDisplayFramerate: RemoteDisplayFramerate
    let forceRemoteScaleToBe1x: Bool
    let codec: VideoCompressionCodec
    let preset: Int
}
