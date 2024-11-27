import AVFoundation
import CTPCircularBuffer
import OSLog
import Opus

private final class TPCircularBufferBox {
    var buffer: TPCircularBuffer

    init(capacity: Int) {
        self.buffer = TPCircularBuffer()
        _TPCircularBufferInit(&self.buffer, UInt32(capacity), MemoryLayout<TPCircularBuffer>.size)
    }

    deinit {
        TPCircularBufferCleanup(&self.buffer)
    }

    var length: Int {
        var len: Int32 = 0
        let _ = TPCircularBufferTail(&self.buffer, &len)

        return Int(len)
    }
}

class AudioBufferNode {
    let format: AVAudioFormat
    var output: AVAudioSourceNode

    private var buffer: TPCircularBufferBox

    /// Returns the number of frames in the buffer.
    var bufferedFrames: Int {
        self.buffer.length / (MemoryLayout<Float32>.size * Int(self.format.channelCount))
    }

    /// Returns the amount of audio buffered, in milliseconds
    var latency: Double {
        Double(self.bufferedFrames) / (self.format.sampleRate / 1000)
    }

    init(format: AVAudioFormat) {
        let capacity =
            Int(format.sampleRate) * Int(format.channelCount) * MemoryLayout<Float32>.size  // 1s
        self.buffer = TPCircularBufferBox(capacity: capacity)
        self.format = format

        let targetFrameCount = Int(40 * (format.sampleRate / 1000))
        let highWatermark = Int(60 * (format.sampleRate / 1000))
        let lowWatermark = Int(20 * (format.sampleRate / 1000))

        weak var bufferRef = self.buffer
        var refillMode = false
        self.output = AVAudioSourceNode { (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let buffer = bufferRef else {
                return -1
            }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            let channels = Int(format.channelCount)
            if ablPointer.count != format.channelCount {
                Logger.attachment.error("wrong number of channels in AVAudioBufferList")
                return -1
            }

            let frameCount = Int(frameCount)

            var len: Int32 = 0
            let buf = TPCircularBufferTail(&buffer.buffer, &len)

            let availableSamples = Int(len) / MemoryLayout<Float32>.size
            let availableFrames = availableSamples / channels
            if buf == nil || availableFrames < lowWatermark
                || (refillMode && availableFrames < targetFrameCount)
            {
                Logger.attachment.debug("silence for \(frameCount)  frames")
                refillMode = true

                // Not enough data; fill with silence
                for buffer in ablPointer {
                    if let out = buffer.mData {
                        memset(out, 0, frameCount * MemoryLayout<Float>.size)
                    }
                }

                return noErr
            } else {
                refillMode = false
            }

            // We have to deinterleave as we do the copy.
            let data = buf!.bindMemory(to: Float32.self, capacity: availableSamples)
            for channel in 0..<channels {
                let out = ablPointer[channel].mData!.assumingMemoryBound(to: Float32.self)
                for frame in 0..<frameCount {
                    out[frame] = data[frame * channels + channel]
                }
            }

            // If we're lagging way behind, skip forward by an integer multiple of the frame size.
            var consumedFrames = frameCount
            if availableFrames > highWatermark {
                let skip = ((availableFrames / frameCount) - 1) * frameCount
                Logger.attachment.debug(
                    "skipping \(skip) additional frames (original \(consumedFrames)")
                consumedFrames += skip
            }

            TPCircularBufferConsume(
                &buffer.buffer, UInt32(consumedFrames * channels * MemoryLayout<Float32>.size))

            return noErr
        }
    }

    // Write audio data to the circular buffer
    func enqueueSamples(_ buf: AVAudioPCMBuffer) {
        precondition(buf.format.commonFormat == .pcmFormatFloat32)
        precondition(buf.format.isInterleaved, "format must be interleaved")
        precondition(
            buf.format.sampleRate == self.format.sampleRate,
            "input/output sample rate must be the same")
        precondition(
            buf.format.channelCount == self.format.channelCount,
            "input/output channel count must be the same")

        if let data = buf.floatChannelData {
            let len = buf.frameLength * buf.format.channelCount * UInt32(MemoryLayout<Float32>.size)
            if !TPCircularBufferProduceBytes(&self.buffer.buffer, data.pointee, len) {
                Logger.attachment.error("buffer overrun")
            }
        }
    }
}
