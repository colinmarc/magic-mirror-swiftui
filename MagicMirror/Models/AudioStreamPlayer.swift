import AVFoundation
import OSLog

protocol AudioStreamPlayer: AnyObject {
    func streamStarted(format: AVAudioFormat)
    func audioFrameAvailable(_ buf: AVAudioPCMBuffer, at pts: UInt64)
    func sync(pts: UInt64, measuredAt: ContinuousClock.Instant)
}

class SyncingAudioEngine: AudioStreamPlayer {
    private let engine = AVAudioEngine()
    private var bufferNode: AudioBufferNode?
    private var format: AVAudioFormat?

    private var engineStarted = false

    private var videoSyncPoint: (UInt64, ContinuousClock.Instant)?

    func streamStarted(format inputFormat: AVAudioFormat) {
        // We use deinterleaved audio between AVAudioNodes. The AudioBufferNode is capable of deinterleaving.
        var format: AVAudioFormat
        if inputFormat.isInterleaved {
            format = AVAudioFormat(
                commonFormat: inputFormat.commonFormat,
                sampleRate: inputFormat.sampleRate,
                channels: inputFormat.channelCount,
                interleaved: false)!
        } else {
            format = inputFormat
        }

        if self.engineStarted {
            self.stop()
        }

        if let bufferNode = self.bufferNode {
            self.engine.disconnectNodeOutput(bufferNode.output)
            self.engine.detach(bufferNode.output)
        }

        let buffer = AudioBufferNode(format: format)
        self.format = format
        self.bufferNode = buffer

        self.engine.attach(buffer.output)
        self.engine.connect(buffer.output, to: engine.mainMixerNode, format: buffer.format)
        self.engine.prepare()

        do {
            try self.engine.start()
            self.engineStarted = true
        } catch {
            Logger.attachment.error("failed to start AVAudioEngine: \(error)")
        }
    }

    func audioFrameAvailable(_ buf: AVAudioPCMBuffer, at pts: UInt64) {
        self.bufferNode?.enqueueSamples(buf)

        // Determine what our audio PTS *should* be.
        //        var targetLatency: Int64 = 30  // Keep at least 30ms in the buffer.
        //        if let (syncPts, syncTime) = self.videoSyncPoint {
        //            let target = Int64(syncPts) + Int64((ContinuousClock.now - syncTime).inMs)
        //            Logger.attachment.debug("target latency: \(target - Int64(pts))")
        //            targetLatency = max(targetLatency, target - Int64(pts))
        //        }
    }

    func sync(pts: UInt64, measuredAt: ContinuousClock.Instant) {
        // Try to avoid over-syncing.
        if let (_, syncTs) = self.videoSyncPoint,
            (ContinuousClock.now - syncTs) > Duration.seconds(1)
        {
            self.videoSyncPoint = (pts, measuredAt)
        }
    }

    func stop() {
        self.engine.stop()
        self.engineStarted = false
    }
}

extension Duration {
    var inMs: Double {
        let (seconds, attoseconds) = self.components
        return Double(seconds) * 1000 + Double(attoseconds) / 1e+15
    }
}
