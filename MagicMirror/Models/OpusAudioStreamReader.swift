import AVFoundation
import MMClientCommon
import OSLog
import Opus

actor OpusAudioStreamReader {
    unowned let player: AudioStreamPlayer
    private let decoder: Opus.Decoder

    nonisolated let format: AVAudioFormat

    init?(player: AudioStreamPlayer, params: MMClientCommon.AudioStreamParams) {
        self.player = player

        guard
            let format = AVAudioFormat(
                opusPCMFormat: .float32,
                sampleRate: Double(params.sampleRate),
                channels: UInt32(params.channels.count))
        else {
            Logger.attachment.error(
                "failed to initialize audio stream (channels: \(params.channels.count), sampleRate: \(params.sampleRate)"
            )

            return nil
        }

        do {
            try self.decoder = Opus.Decoder(format: format, application: .audio)
        } catch {
            Logger.attachment.error(
                "failed to initialize audio stream (channels: \(params.channels.count), sampleRate: \(params.sampleRate): \(error)"
            )
            return nil
        }

        self.format = format
    }

    func recvPacket(_ packet: Packet) {
        do {
            let decoded = try self.decoder.decode(packet.data())
            self.player.audioFrameAvailable(decoded, at: packet.pts())
        } catch {
            Logger.attachment.error("failed to decode Opus packet: \(error)")
            return
        }
    }
}
