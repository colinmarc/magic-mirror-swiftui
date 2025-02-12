import MetalKit
import OSLog
import VideoToolbox

// TODO: bubble up errors rather than crashing

private struct EnqueuedFrame {
    let buffer: CVPixelBuffer
    let callback: () -> Void
}

class AttachmentDecompressionSession: VideoStreamPlayer {
    var decoder: VTDecompressionSession?
    var formatDesc: CMFormatDescription?

    var renderer: AttachmentRenderer

    init(renderer: AttachmentRenderer) {
        self.renderer = renderer
    }

    func formatDescriptionChanged(desc: CMFormatDescription) {
        self.formatDesc = desc
        if let decoder = self.decoder,
            !VTDecompressionSessionCanAcceptFormatDescription(decoder, formatDescription: desc)
        {
            self.decoder = nil
        }

        let size = CMVideoFormatDescriptionGetDimensions(desc)
        let colorspace = desc.colorspace

        self.renderer.updateTextureProperties(
            size: CGSize(width: CGFloat(size.width), height: CGFloat(size.height)),
            colorspace: colorspace)
    }

    func videoFrameAvailable(buf: CMSampleBuffer, callback: (() -> Void)?) {
        if self.formatDesc == nil {
            self.formatDesc = CMSampleBufferGetFormatDescription(buf)
        }

        if self.decoder == nil {
            guard let formatDesc = self.formatDesc else {
                Logger.renderer.error("no format description available for video frame")
                return
            }

            let config: NSDictionary = [
                String(kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder): true
            ]

            let bufferAttributes: NSDictionary = [
                String(kCVPixelBufferMetalCompatibilityKey): true
            ]

            let status = VTDecompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                formatDescription: formatDesc,
                decoderSpecification: config,
                imageBufferAttributes: bufferAttributes,
                decompressionSessionOut: &self.decoder)
            if status != noErr || self.decoder == nil {
                Logger.attachment.error("failed to create VTDecompressionSession: \(status)")
                return
            }
        }

        var flags: VTDecodeInfoFlags = VTDecodeInfoFlags()
        let status = VTDecompressionSessionDecodeFrame(
            self.decoder!, sampleBuffer: buf, flags: ._EnableAsynchronousDecompression,
            infoFlagsOut: &flags,
            outputHandler: {
                status, _, imageBuffer, _, _ in

                if status != noErr {
                    Logger.renderer.error("VTDecompressionSession callback error: \(status)")
                    return
                }

                guard let image = imageBuffer else {
                    Logger.renderer.debug("VTDecompressionSession callback called with nil buffer")
                    return
                }

                //            Logger.renderer.debug("buf: \(String(describing: image))")

                //            let colorspace: String = String(describing: CVImageBufferGetColorSpace(image))
                //            let width = CVPixelBufferGetWidth(image)
                //            let height = CVPixelBufferGetHeight(image)
                //
                //            Logger.renderer.debug("in frame callback dims: \(width)x\(height), format: \(image.cvPixelFormat.description), depth: \(image.bytesPerRow(of: 0)), colorspace: \(colorspace)")

                // Trigger the frame to draw.
                Task {
                    DispatchQueue.main.sync {
                        self.renderer.enqueueFrame(image, callback: callback ?? {})
                    }
                }
            })

        if status != noErr {
            Logger.renderer.error("VTDecompressionSessionDecodeFrame error: \(status)")
            return
        }
    }
}

@MainActor
class AttachmentRenderer: NSObject, MTKViewDelegate {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var library: MTLLibrary
    private var pipelineState: MTLRenderPipelineState

    private var latestFrame: EnqueuedFrame?

    private var textureCache: CVMetalTextureCache

    private var videoDimensions: CGSize
    private var viewDimensions: CGSize
    private var viewPort: CGRect

    var view: MTKView

    private var needsClear: Bool = false

    #if DEBUG
        private var signposter = OSSignposter(logger: .renderer)
        private var latestFrameSignpost: (OSSignpostID, OSSignpostIntervalState)?
    #endif

    init(_ view: MTKView) {
        self.view = view

        self.videoDimensions = CGSize()
        self.viewDimensions = view.bounds.size
        self.viewPort = CGRect(
            x: 0, y: 0,
            width: view.bounds.width,
            height: view.bounds.height)

        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
        self.library = device.makeDefaultLibrary()!

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

        do {
            try self.pipelineState = device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("failed to create attachmentRenderer")
        }

        var textureCache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault, nil, self.device, nil, &textureCache)
        if status != kCVReturnSuccess || textureCache == nil {
            fatalError("failed to create CVMetalTextureCache: \(status)")
        } else {
            self.textureCache = textureCache!
        }

        super.init()

        view.delegate = self
        view.device = device
        view.clearColor = .init()
        view.autoResizeDrawable = true
        view.isPaused = true

        // TODO: better to use CVDisplayLink
        view.preferredFramesPerSecond = 120

        #if os(macOS)
            (view.layer as? CAMetalLayer)?.displaySyncEnabled = false
        #endif
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.view = view
        self.viewDimensions = size
        recalculateViewport()
    }

    func updateTextureProperties(size: CGSize, colorspace: CGColorSpace?) {
        self.videoDimensions = size
        self.recalculateViewport()

        guard let layer = self.view.layer as? CAMetalLayer else {
            Logger.renderer.debug("unable to set colorspace")
            return
        }

        layer.colorspace = colorspace ?? CGColorSpace.init(name: CGColorSpace.itur_709)!
    }

    private func recalculateViewport() {
        if viewDimensions.width == 0 || viewDimensions.height == 0
            || videoDimensions.width == 0 || videoDimensions.height == 0
        {
            self.viewPort = CGRect()
            return
        }

        let viewAspect = viewDimensions.width / viewDimensions.height
        let videoAspect = videoDimensions.width / videoDimensions.height

        var width: Double
        var height: Double
        var originX: Double = 0
        var originY: Double = 0

        if videoAspect > viewAspect {
            // View too tall.
            width = viewDimensions.width
            height = width / videoAspect
            originY = (viewDimensions.height - height) / 2
        } else {
            // View too wide.
            height = viewDimensions.height
            width = height * videoAspect
            originX = (viewDimensions.width - width) / 2
        }

        self.viewPort = CGRect(
            x: originX, y: originY,
            width: width, height: height)
    }

    /// Returns the position of the cursor over the video texture, where [0, 0]
    /// is the top-left corner and [1, 1] is the bottom-right. Returns nil if
    /// the point is within the letterbox.
    func convertToTextureCoords(from viewCoords: CGPoint) -> CGPoint? {
        // Convert to a reasonable coordinate system.
        let bounds = self.view.bounds
        let backing = self.view.convertToBacking(
            CGPoint(x: viewCoords.x, y: (bounds.height - viewCoords.y)))

        // Check if there's a letterbox.
        if self.viewPort.contains(backing) {
            return CGPoint(
                x: (backing.x - self.viewPort.origin.x) / self.viewPort.width,
                y: (backing.y - self.viewPort.origin.y) / self.viewPort.height)
        } else {
            return nil
        }
    }

    /// Returns the position of the cursor in the view, in the standard NSView coordinate system,
    /// for a given point in texture coordinates ([0, 0] -> [1,1], with the origin in the top-left position)
    func convertToViewCoords(from uv: CGPoint) -> CGPoint {
        let x = uv.x * self.viewPort.width
        let y = self.viewPort.height - (uv.y * self.viewPort.height)

        let backing = CGPoint(
            x: self.viewPort.origin.x + x,
            y: self.viewPort.origin.y + y)

        return self.view.convertFromBacking(backing)
    }

    /// Scales a relative motion vector from the view space to texture space ([0, 0] -> [1,1], with the origin in the top-left position).
    func convertToTextureVector(from viewVector: (Double, Double)) -> (Double, Double) {
        // Scale to backing coordinates first.
        let scaleFactor = self.view.window?.backingScaleFactor ?? 1
        return (
            viewVector.0 * scaleFactor / self.videoDimensions.width,
            viewVector.1 * scaleFactor / self.videoDimensions.height
        )
    }

    func clear() {
        self.needsClear = true
        self.view.draw()
    }

    func enqueueFrame(_ frame: CVPixelBuffer, callback: @escaping () -> Void) {
        self.needsClear = false
        self.latestFrame = EnqueuedFrame(buffer: frame, callback: callback)

        #if DEBUG
            if let (id, state) = self.latestFrameSignpost.take() {
                self.signposter.emitEvent("frame discarded", id: id)
                self.signposter.endInterval("renderFrame", state)
            }

            let id = self.signposter.makeSignpostID()
            let state = self.signposter.beginInterval("renderFrame", id: id)
            self.latestFrameSignpost = (id, state)
        #endif

        self.view.draw()
    }

    func draw(in view: MTKView) {
        guard let frame = self.latestFrame.take() else {
            if self.needsClear,
                let cmd = self.commandQueue.makeCommandBuffer(),
                let descriptor = view.currentRenderPassDescriptor,
                let encoder = cmd.makeRenderCommandEncoder(descriptor: descriptor)
            {
                // Clear black.
                descriptor.colorAttachments[0].loadAction = .clear
                descriptor.colorAttachments[0].storeAction = .store
                descriptor.colorAttachments[0].clearColor = .init()

                encoder.endEncoding()
                if let currentDrawable = view.currentDrawable {
                    cmd.present(currentDrawable)
                }

                cmd.commit()
            } else {
                Logger.renderer.error("failed to prepare render pass for clear")
            }

            self.needsClear = false
            return
        }

        guard let format = frame.buffer.matchingTextureFormat else {
            Logger.renderer.error(
                "unable to determine matching MTLPixelFormat for \(frame.buffer.cvPixelFormat.description)"
            )
            return
        }

        var mtlTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, self.textureCache, frame.buffer, nil,
            format, frame.buffer.width, frame.buffer.height, 0, &mtlTexture)
        guard mtlTexture != nil, let texture = CVMetalTextureGetTexture(mtlTexture!),
            status == kCVReturnSuccess
        else {
            Logger.renderer.error("error getting metal texture for frame: \(status)")
            return
        }

        let descriptor = MTLCommandBufferDescriptor()
        //        #if DEBUG
        //        descriptor.errorOptions = .encoderExecutionStatus
        //        #endif

        if let cmd = self.commandQueue.makeCommandBuffer(descriptor: descriptor),
            let descriptor = view.currentRenderPassDescriptor,
            let encoder = cmd.makeRenderCommandEncoder(descriptor: descriptor)
        {
            encoder.setViewport(
                MTLViewport(
                    originX: self.viewPort.origin.x, originY: self.viewPort.origin.y,
                    width: self.viewPort.width, height: self.viewPort.height, znear: 0.0, zfar: 1.0)
            )
            encoder.setRenderPipelineState(pipelineState)

            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

            encoder.endEncoding()
            if let currentDrawable = view.currentDrawable {
                cmd.present(currentDrawable)
            }

            // Unclear if this works to release the texture.
            cmd.addCompletedHandler { _ in mtlTexture = nil }

            //            #if DEBUG
            //            // Try to report errors.
            //            cmd.addCompletedHandler(AttachmentRenderer.debugCompletionHandler)
            //            #endif

            cmd.commit()
        } else {
            Logger.renderer.error("failed to prepare render pass")
        }

        #if DEBUG
            if let (_, state) = self.latestFrameSignpost.take() {
                self.signposter.endInterval("renderFrame", state)
            }
        #endif

        frame.callback()
    }

    static func debugCompletionHandler(cmd: MTLCommandBuffer) {
        for log in cmd.logs {
            let encoderLabel = log.encoderLabel ?? "UNKNOWN"
            Logger.renderer.debug("Faulting encoder \"\(encoderLabel)\"")
            guard let debugLocation = log.debugLocation,
                let functionName = debugLocation.functionName
            else {
                continue
            }

            Logger.renderer.debug(
                "Traceback \(functionName):\(debugLocation.line):\(debugLocation.column)")
        }

        if let error = cmd.error as NSError?,
            let encoderInfos = error.userInfo[MTLCommandBufferEncoderInfoErrorKey]
                as? [MTLCommandBufferEncoderInfo]
        {
            for info in encoderInfos {
                let msg = info.label + info.debugSignposts.joined()
                Logger.renderer.error("GPU error: \(msg, privacy: .public)")
            }
        }
    }
}

extension CMVideoFormatDescription {
    var colorspace: CGColorSpace? {
        //        guard let if let inputFormatDescriptionExtension = CMFormatDescriptionGetExtensions(inputFormatDescription) as Dictionary? {
        //            let colorPrimaries = inputFormatDescriptionExtension[kCVImageBufferColorPrimariesKey]
        guard let inputFormatDescription = CMFormatDescriptionGetExtensions(self) as Dictionary?
        else {
            return nil
        }

        let primaries =
            inputFormatDescription[kCMFormatDescriptionExtension_ColorPrimaries] as! CFString?
        let matrix = inputFormatDescription[kCMFormatDescriptionExtension_YCbCrMatrix] as! CFString?
        let tf =
            inputFormatDescription[kCMFormatDescriptionExtension_TransferFunction] as! CFString?

        switch (primaries, matrix, tf) {
        case (_, _, kCMFormatDescriptionTransferFunction_sRGB):
            return CGColorSpace(name: CGColorSpace.sRGB)
        case (
            kCMFormatDescriptionColorPrimaries_ITU_R_709_2,
            kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2,
            kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2
        ):
            return CGColorSpace(name: CGColorSpace.itur_709)
        case (
            kCMFormatDescriptionColorPrimaries_ITU_R_2020,
            kCMFormatDescriptionYCbCrMatrix_ITU_R_2020,
            kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ
        ):
            return CGColorSpace(name: CGColorSpace.itur_2100_PQ)
        case (
            kCMFormatDescriptionColorPrimaries_ITU_R_2020,
            kCMFormatDescriptionYCbCrMatrix_ITU_R_2020,
            kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG
        ):
            return CGColorSpace(name: CGColorSpace.itur_2100_HLG)
        default:
            Logger.renderer.debug("failed to determine colorspace for \(primaries)/\(matrix)/\(tf)")
            return nil
        }
    }
}

let kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarFullRange = 0x2D78_6630 as OSType  // -xf0
let kCVPixelFormatType_Lossless_422YpCbCr10PackedBiPlanarFullRange = 0x2678_6632 as OSType  // &xf2
let kCVPixelFormatType_Lossy_422YpCbCr10PackedBiPlanarFullRange = 0x2D78_6632 as OSType  // -xf2

let kCVPixelFormatType_420YpCbCr10PackedBiPlanarFullRange = 0x7066_3230 as OSType  // pf20
let kCVPixelFormatType_422YpCbCr10PackedBiPlanarFullRange = 0x7066_3232 as OSType  // pf22
let kCVPixelFormatType_444YpCbCr10PackedBiPlanarFullRange = 0x7066_3434 as OSType  // pf44

let kCVPixelFormatType_420YpCbCr10PackedBiPlanarVideoRange = 0x7034_3230 as OSType  // p420
let kCVPixelFormatType_422YpCbCr10PackedBiPlanarVideoRange = 0x7034_3232 as OSType  // p422
let kCVPixelFormatType_444YpCbCr10PackedBiPlanarVideoRange = 0x7034_3434 as OSType  // p444

let MTLPixelFormatYCBCR8_420_2P: UInt = 500
let MTLPixelFormatYCBCR8_422_2P: UInt = 502
let MTLPixelFormatYCBCR8_444_2P: UInt = 503
let MTLPixelFormatYCBCR10_420_2P: UInt = 505
let MTLPixelFormatYCBCR10_422_2P: UInt = 506
let MTLPixelFormatYCBCR10_444_2P: UInt = 507
let MTLPixelFormatYCBCR10_420_2P_PACKED: UInt = 508
let MTLPixelFormatYCBCR10_422_2P_PACKED: UInt = 509
let MTLPixelFormatYCBCR10_444_2P_PACKED: UInt = 510

extension CVPixelBuffer {
    var matchingTextureFormat: MTLPixelFormat? {
        switch self.cvPixelFormat.rawValue {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarFullRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR8_420_2P)
        case kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_422YpCbCr8BiPlanarFullRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR8_422_2P)
        case kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_444YpCbCr8BiPlanarFullRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR8_444_2P)
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR10_420_2P)
        case kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange,
            kCVPixelFormatType_422YpCbCr10BiPlanarFullRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR10_422_2P)
        case kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange,
            kCVPixelFormatType_444YpCbCr10BiPlanarFullRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR10_444_2P)
        case kCVPixelFormatType_420YpCbCr10PackedBiPlanarVideoRange,
            kCVPixelFormatType_420YpCbCr10PackedBiPlanarFullRange,
            kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarVideoRange,
            kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarFullRange,
            kCVPixelFormatType_Lossless_420YpCbCr10PackedBiPlanarVideoRange,
            kCVPixelFormatType_Lossless_420YpCbCr10PackedBiPlanarFullRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR10_420_2P_PACKED)
        case kCVPixelFormatType_444YpCbCr10PackedBiPlanarFullRange,
            kCVPixelFormatType_444YpCbCr10PackedBiPlanarVideoRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR10_444_2P_PACKED)
        case kCVPixelFormatType_422YpCbCr10PackedBiPlanarVideoRange,
            kCVPixelFormatType_422YpCbCr10PackedBiPlanarFullRange,
            kCVPixelFormatType_Lossy_422YpCbCr10PackedBiPlanarVideoRange,
            kCVPixelFormatType_Lossy_422YpCbCr10PackedBiPlanarFullRange,
            kCVPixelFormatType_Lossless_422YpCbCr10PackedBiPlanarVideoRange,
            kCVPixelFormatType_Lossless_422YpCbCr10PackedBiPlanarFullRange:
            return MTLPixelFormat.init(rawValue: MTLPixelFormatYCBCR10_422_2P_PACKED)
        default:
            return nil
        }
    }
}
