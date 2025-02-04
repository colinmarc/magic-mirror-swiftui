import AVFoundation
import MMClientCommon
import os

@MainActor
class VideoStreamReader {
    unowned let player: VideoStreamPlayer

    var streamSeq: UInt64
    var streamParams: VideoStreamParams

    init(
        player: VideoStreamPlayer, streamSeq: UInt64, streamParams: VideoStreamParams
    ) {
        self.player = player
        self.streamSeq = streamSeq
        self.streamParams = streamParams

        if ![.h264, .h265].contains(streamParams.codec) {
            preconditionFailure("codec not supported: \(streamParams.codec)")
        }
    }

    private var needsReset: Bool = false
    private var formatDesc: CMVideoFormatDescription? = .none
    private var memPool: CMMemoryPool = CMMemoryPoolCreate(options: nil)

    private var allocator: CFAllocator {
        CMMemoryPoolGetAllocator(self.memPool)
    }

    func reset(streamSeq: UInt64, params: VideoStreamParams) {
        Logger.attachment.info(
            "video stream start: \(streamSeq), \(params.codec) \(params.width)x\(params.height)"
        )

        self.streamSeq = streamSeq
        self.streamParams = params
        self.formatDesc = .none
        self.needsReset = true
    }

    func recvPacket(_ packet: Packet, callback: @escaping () -> Void) {
        if packet.streamSeq() != self.streamSeq {
            return
        }

        let blockBuffer: CMBlockBuffer
        switch self.streamParams.codec {
        case .h264, .h265:
            switch parseH2645VideoPacket(packet, codec: self.streamParams.codec) {
            case .failure(let err):
                Logger.attachment.error(
                    "failed to parse video packet: \(err, privacy: .public)")
                return
            case .success(nil):
                return
            case .success(.some(let buf)):
                blockBuffer = buf
            }
        default:
            preconditionFailure("unknown codec")
        }

        // The packet PTS is milliseconds with an arbitrary epoch.
        // let pts = CMTime(value: Int64(packet.pts()) * 60, timescale: 60_000)
        // let timing = CMSampleTimingInfo(
        // duration: CMTime.invalid, presentationTimeStamp: pts, decodeTimeStamp: .invalid)

        if self.formatDesc == nil {
            Logger.attachment.error("no format description found")
            return
        }

        var sampleBuffer: CMSampleBuffer? = nil
        let status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault, dataBuffer: blockBuffer,
            formatDescription: self.formatDesc!,
            sampleCount: 1, sampleTimingEntryCount: 0, sampleTimingArray: nil,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer)
        if status != noErr || sampleBuffer == nil {
            Logger.attachment.error("failed to create CMSampleBuffer: \(status)")
            return
        }

        let buf = sampleBuffer!
        buf.setOpt(true, forKey: kCMSampleAttachmentKey_DisplayImmediately)
        buf.setOpt(true, forKey: kCMSampleBufferAttachmentKey_EndsPreviousSampleDuration)
        if self.needsReset {
            buf.setOpt(true, forKey: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding)
            self.needsReset = false
        }

        self.player.videoFrameAvailable(buf: buf, callback: callback)
    }

    private func parseH2645VideoPacket(_ packet: Packet, codec: VideoCodec) -> Result<
        CMBlockBuffer?, ParseError
    > {
        let data = packet.data()

        // We make a few assumptions here about the bitstream that aren't really
        // kosher, but are fine in practice and massively simplifying:
        //  - We assume that the headers appear first in the packet.
        //  - We assume that the headers appear together, not distributed across
        //    packets.
        // Both of those assumptions are checked here and result in errors if
        // violated.
        var parameterSetCount = 0
        var finishedWithParameterSets = false
        var naluOffsets: [Int] = []
        var naluTypes: [UInt8] = []
        while true {
            let searchOffset =
                if let last = naluOffsets.last {
                    last + 4
                } else {
                    Int(0)
                }

            guard let off = nextNalu(data, searchOffset: searchOffset) else {
                break
            }

            naluOffsets.append(off)

            let naluType =
                switch codec {
                case .h264:
                    data[off + 3] & 0x1F
                case .h265:
                    (data[off + 3] & 0x7E) >> 1
                default:
                    preconditionFailure()
                }

            naluTypes.append(naluType)
            if (codec == .h264 && [7, 8, 13].contains(naluType))
                || (codec == .h265 && [32, 33, 34].contains(naluType))
            {
                if finishedWithParameterSets {
                    return .failure(.invalidBitstream("parameter set after slice in packet"))
                }

                parameterSetCount += 1
            } else {
                finishedWithParameterSets = true
            }
        }

        if naluOffsets.isEmpty {
            return .failure(.invalidBitstream("no NALUs in packet"))
        }

        var naluSizes = [Int](repeating: 0, count: naluOffsets.count)
        for (idx, offset) in naluOffsets.enumerated() {
            if idx < (naluOffsets.count - 1) {
                naluSizes[idx] = naluOffsets[idx + 1] - offset
            } else {
                naluSizes[idx] = data.count - offset
            }
        }

        // Only the non-parameter-set NALUs get shipped in the block buffer.
        if parameterSetCount > 0 {
            Logger.attachment.debug(
                "found \(parameterSetCount) parameter sets, sizes \(naluSizes.prefix(parameterSetCount), privacy: .public)"
            )

            // PPS and SPS should be together.
            if parameterSetCount < 2 {
                return .failure(.invalidBitstream("only one parameter set in packet"))
            }

            let parameterSetSizes = Array(naluSizes.prefix(parameterSetCount))
            let status = data.withUnsafeBytes { (dataPtr: UnsafeRawBufferPointer) in
                let ptrs = naluOffsets.prefix(parameterSetCount).map { off in
                    return dataPtr.bindMemory(to: UInt8.self).baseAddress!.advanced(by: off + 3)
                }

                if codec == .h264 {
                    return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                        allocator: kCFAllocatorDefault, parameterSetCount: parameterSetCount,
                        parameterSetPointers: ptrs, parameterSetSizes: parameterSetSizes,
                        nalUnitHeaderLength: 4, formatDescriptionOut: &self.formatDesc)
                } else if codec == .h265 {
                    return CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault, parameterSetCount: parameterSetCount,
                        parameterSetPointers: ptrs,
                        parameterSetSizes: parameterSetSizes,
                        nalUnitHeaderLength: 4, extensions: nil,
                        formatDescriptionOut: &self.formatDesc)
                } else {
                    preconditionFailure(
                        "codec in parseH2645VideoPacket must be h264 or h265, is \(codec)")
                }
            }

            if status != noErr || self.formatDesc == nil {
                return .failure(.invalidBitstream("failed to import parameter sets: \(status)"))
            } else if let formatDesc = self.formatDesc {
                self.player.formatDescriptionChanged(desc: formatDesc)
            }

            self.needsReset = true
            if naluOffsets.count <= parameterSetCount {
                return .success(nil)
            }
        }

        // We only ship the non-parameter-set NALUs.
        naluOffsets = Array(naluOffsets.suffix(from: parameterSetCount))
        naluSizes = Array(naluSizes.suffix(from: parameterSetCount))

        var status: OSStatus

        // Add one byte per NALU to account for 3-byte start codes vs 4-byte
        // length prefixes.
        let blockBufferSize = naluSizes.makeIterator().reduce(0, +) + naluSizes.count
        var blockBuffer: CMBlockBuffer? = nil
        status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: blockBufferSize,
            blockAllocator: self.allocator, customBlockSource: nil, offsetToData: 0,
            dataLength: blockBufferSize, flags: 0, blockBufferOut: &blockBuffer)
        if status != noErr {
            return .failure(.importFailed(status))
        }

        status = CMBlockBufferAssureBlockMemory(blockBuffer!)
        if status != noErr {
            return .failure(.importFailed(status))
        }

        var outOffset = 0
        for (idx, off) in naluOffsets.enumerated() {
            let size = naluSizes[idx] - 3

            // Write four bytes of length.
            let sizeBytes = withUnsafeBytes(of: UInt32(size).bigEndian, Array.init)
            status = CMBlockBufferReplaceDataBytes(
                with: sizeBytes, blockBuffer: blockBuffer!, offsetIntoDestination: outOffset,
                dataLength: 4)
            if status != noErr {
                return .failure(.importFailed(status))
            }

            // Write the data for the nalu, without the three-byte start code.
            status = data.withUnsafeBytes { (dataPtr: UnsafeRawBufferPointer) in
                let ptr = dataPtr.bindMemory(to: UInt8.self).baseAddress!.advanced(by: off + 3)
                return CMBlockBufferReplaceDataBytes(
                    with: ptr, blockBuffer: blockBuffer!, offsetIntoDestination: outOffset + 4,
                    dataLength: size)
            }
            if status != noErr {
                return .failure(.importFailed(status))
            }

            // Advance to the next NALU.
            outOffset += size + 4
        }

        if status != noErr {
            return .failure(.importFailed(status))
        }

        return .success(blockBuffer!)
    }
}

enum ParseError: Error, CustomStringConvertible {
    case unsupportedCodec(VideoCodec)
    case invalidBitstream(String)
    case importFailed(OSStatus)

    var description: String {
        switch self {
        case .unsupportedCodec(let codec):
            "Unsupported codec: \(codec)"
        case .invalidBitstream(let reason):
            "Invalid bitstream: \(reason)"
        case .importFailed(let status):
            "Failed to import NALUs: \(status)"
        }
    }
}

/// Finds the offset of the next [0x0, 0x0, 0x1, NALU_TYPE] sequence in the
/// buffer.
private func nextNalu(_ data: Data, searchOffset: Int) -> Int? {
    var off = Int(searchOffset)
    while true {
        if (data.count - off) <= 4 {
            return nil
        } else if data[off + 2] > 0x01 {
            off += 3
        } else if data[off + 1] > 0x00 {
            off += 2
        } else if data[off] > 0x00 || data[off + 2] != 0x01 {
            off += 1
        } else {
            return off
        }
    }
}

extension CMSampleBuffer {
    fileprivate func setOpt(_ value: Any?, forKey key: NSString) {
        let arr = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true)! as NSArray
        (arr[0] as! NSMutableDictionary).setValue(value, forKey: key as String)
    }
}
