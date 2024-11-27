import AVFoundation
import os

protocol VideoStreamPlayer: AnyObject {
    func formatDescriptionChanged(desc _: CMFormatDescription)
    func videoFrameAvailable(buf _: CMSampleBuffer, callback: (() -> Void)?)
}

extension AVSampleBufferDisplayLayer: VideoStreamPlayer {
    func videoFrameAvailable(buf: CMSampleBuffer, callback: (() -> Void)?) {
        self.sampleBufferRenderer.enqueue(buf)

        if let err = self.sampleBufferRenderer.error {
            Logger.general.error("AVSampleBufferDIsplayLayer error: \(err)")
        }
    }

    func formatDescriptionChanged(desc: CMFormatDescription) {}
}
