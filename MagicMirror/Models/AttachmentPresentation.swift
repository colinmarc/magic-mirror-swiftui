import AVFoundation
import MMClientCommon
import Opus
import SwiftUI
import Synchronization
import os

enum AttachmentPresentationStatus {
    case none
    case connected
    case operation(String)
    case liveOperation(String)
    case errored(AttachmentPresentationError, MMClientCommon.ClientError?)
    case ended

    static func errored(withClientError err: MMClientCommon.ClientError) -> Self {
        .errored(AttachmentPresentationError(for: err), err)
    }

    var needsOverlay: Bool {
        switch self {
        case .connected:
            return false
        default:
            return true
        }
    }

    var isConnected: Bool {
        switch self {
        case .connected, .liveOperation(_):
            return true
        default:
            return false
        }
    }

    var isSome: Bool {
        switch self {
        case .none, .ended:
            return false
        default:
            return true
        }
    }
}

enum AttachmentPresentationError: Error {
    case sessionDoesNotExist
    case timeout
    case server
    case unknown

    init(for clientError: MMClientCommon.ClientError) {
        switch clientError {
        case ClientError.RequestTimeout(_), ClientError.Canceled(_):
            self = .timeout
        case ClientError.ServerError(_):
            self = .server
        default:
            self = .unknown
        }
    }

    var localizedDescription: String {
        switch self {
        case .sessionDoesNotExist:
            "That session does not exist."
        case .timeout:
            "The operation timed out."
        case .server:
            "A server error occured."
        case .unknown:
            "An error occured."
        }
    }
}

@MainActor
protocol AttachmentPresentationDelegate {
    associatedtype VideoPlayer: VideoStreamPlayer
    associatedtype AudioPlayer: AudioStreamPlayer
    var videoPlayer: VideoPlayer { get }
    var audioPlayer: AudioPlayer { get }

    func didAttach(_ attachment: MMClientCommon.Attachment)
    func didDetach()
    func updateCursor(icon: MMClientCommon.CursorIcon, image: NSImage?, hotspot: CGPoint)
    func lockPointer(to location: CGPoint)
    func releasePointer()
}

@Observable @MainActor
class AttachmentPresentation {
    private var currentAttachment: Attachment?

    /// The presentatable status; either the attachment itself, an error, or a
    /// a message indicating a running operation.
    var status: AttachmentPresentationStatus {
        if let att = self.currentAttachment {
            att.status
        } else {
            .none
        }
    }

    /// A handle to the attachment, for sending client-generated events.
    var handle: MMClientCommon.Attachment? {
        self.currentAttachment?.attachment
    }

    /// The current attachment configuration.
    var config: MMClientCommon.AttachmentConfig? {
        self.currentAttachment?.config
    }

    var delegate: (any AttachmentPresentationDelegate)?

    /// Attaches to a session, after optionally resizing the remote display.
    func attach(
        to server: Server, session: Session, updatedDisplayParams: DisplayParams? = .none,
        codec: VideoCodec = .h265, qualityPreset: Int = 7
    ) {
        var initialStatus: AttachmentPresentationStatus
        if let attachment = self.currentAttachment.take() {
            attachment.enableEventPropogation = false
            Task {
                Logger.attachment.debug("detaching old session")
                await attachment.detach()
            }

            if let params = updatedDisplayParams, attachment.session?.displayParams != params {
                initialStatus = .liveOperation("Resizing virtual display...")
            } else {
                initialStatus = .connected
            }
        } else {
            initialStatus = .operation("Resizing virtual display...")
        }

        self.currentAttachment = Attachment(
            to: server,
            parent: self,
            delegate: self.delegate!,
            initialStatus: initialStatus
        ) {
            await server.reloadSessions()
            guard var session = server.sessions[session.id] else {
                throw AttachmentPresentationError.sessionDoesNotExist
            }

            if let params = updatedDisplayParams, session.displayParams != params {
                let client = try await server.connect()

                Logger.attachment.info(
                    "resizing session \(session.id) to \(params.width)x\(params.height)"
                )
                try await client.updateSessionDisplayParams(
                    id: session.id, params: params, timeout: 10.0)

                session.displayParams = params

                // Update the server state for the session.
                server.sessions[session.id]?.displayParams = params
            }

            let config = AttachmentConfig(
                width: session.displayParams.width, height: session.displayParams.height,
                codec: codec, qualityPreset: UInt32(qualityPreset))
            return (session, config)
        }
    }

    /// Launches an app and attaches to it.
    func attach(
        to server: Server, applicationID: String, displayParams: DisplayParams,
        codec: VideoCodec = .h265, qualityPreset: Int = 7, gamepads: [Gamepad] = []
    ) {
        if let attachment = self.currentAttachment.take() {
            Task {
                Logger.attachment.debug("detaching old session")
                await attachment.detach()
            }
        }

        self.currentAttachment = Attachment(
            to: server,
            parent: self,
            delegate: self.delegate!,
            initialStatus: .operation("Launching application \"\(applicationID)\"")
        ) {
            Logger.attachment.info(
                "launching session for app \"\(applicationID, privacy: .public)\"")

            let session = try await server.connect().launchSession(
                applicationId: applicationID,
                displayParams: displayParams,
                permanentGamepads: gamepads,
                timeout: 30.0)

            Logger.attachment.info(
                "launched session \(session.id) for app \"\(applicationID, privacy: .public))\""
            )

            // Make sure the new session gets displayed in the browser view.
            Task.detached {
                await server.reloadSessions()
            }

            let config = AttachmentConfig(
                width: session.displayParams.width, height: session.displayParams.height,
                codec: codec, qualityPreset: UInt32(qualityPreset))

            return (session, config)
        }
    }

    /// (Re-)attaches with the last used configuration.
    func attachWithLastConfiguration() {
        guard let attachment = self.currentAttachment.take(),
            let sessionID = attachment.session?.id
        else {
            return
        }

        attachment.enableEventPropogation = false
        Task {
            Logger.attachment.debug("detaching old session")
            await attachment.detach()
        }

        let server = attachment.server
        self.currentAttachment = Attachment(
            to: server,
            parent: self,
            delegate: self.delegate!,
            initialStatus: .connected
        ) {
            await server.reloadSessions()
            guard let session = server.sessions[sessionID] else {
                throw AttachmentPresentationError.sessionDoesNotExist
            }

            Logger.attachment.info("reattaching to session \(session.id)")
            let config = AttachmentConfig(
                width: session.displayParams.width, height: session.displayParams.height,
                codec: attachment.config?.videoCodec ?? .h265)
            return (session, config)
        }

    }

    /// Updates the display params of the current session and transparently reconnects.
    func updateDisplayParamsLive(with params: DisplayParams) {
        guard let attachment = self.currentAttachment else {
            return
        }

        Task {
            await attachment.updateDisplayParamsLive(with: params)
        }
    }

    /// Closes the current attachment, if any, and resets the presentation.
    func detach() {
        guard let attachment = self.currentAttachment else {
            return
        }

        Task {
            await attachment.detach()
        }
    }

}

@Observable @MainActor
private class Attachment {
    var enableEventPropogation: Bool = true {
        didSet {
            if !enableEventPropogation {
                self.audioStream = nil
                self.videoStream = nil
            } else {
                preconditionFailure("can't enable event propogation again")
            }
        }
    }
    private(set) var status: AttachmentPresentationStatus

    private var setupTask: Task<Void, Never>? = nil

    let server: Server
    private(set) var session: Session? = nil
    private(set) var config: AttachmentConfig? = nil
    private(set) var attachment: MMClientCommon.Attachment? = nil

    private weak var parent: AttachmentPresentation?
    private let superDelegate: any AttachmentPresentationDelegate

    private var videoStream: VideoStreamReader?
    private var audioStream: OpusAudioStreamReader?

    init(
        to server: Server,
        parent: AttachmentPresentation,
        delegate: any AttachmentPresentationDelegate,
        initialStatus: AttachmentPresentationStatus,
        setup: @escaping () async throws -> (Session, AttachmentConfig)
    ) {
        self.server = server
        self.parent = parent
        self.superDelegate = delegate
        self.status = initialStatus

        self.setupTask = Task {
            do {
                let (session, config) = try await setup()
                self.session = session
                self.config = config

                if self.enableEventPropogation {
                    Logger.attachment.info("attaching to session \(session.id)")

                    self.status = .operation("Connecting to session...")
                    let handle = try await server.attachSession(
                        sessionID: session.id, config: config, delegate: self)

                    self.attachment = handle
                    self.status = .connected
                    if self.enableEventPropogation {
                        self.superDelegate.didAttach(handle)
                    }
                }
            } catch let err as AttachmentPresentationError {
                self.status = .errored(err, nil)
            } catch let ce as MMClientCommon.ClientError {
                Logger.attachment.error(
                    "attachment failed: \(ce.localizedDescription, privacy: .public)")
                self.status = .errored(withClientError: ce)
            } catch {
                Logger.attachment.error(
                    "attachment failed: \(error.localizedDescription, privacy: .public)")
                self.status = .errored(.unknown, nil)
            }
        }

    }

    func updateDisplayParamsLive(with params: DisplayParams) async {
        let _ = await self.setupTask?.result
        guard let session = self.session,
            self.enableEventPropogation,
            self.attachment != nil
        else {
            return
        }

        if session.displayParams == params {
            Logger.attachment.info("not updating session, display params are the same")
            return
        }

        do {
            Logger.attachment.debug("initiating live resize operation for session: \(session.id)")

            self.status = .liveOperation("Resizing virtual display...")
            let client = try await server.connect()
            try await client.updateSessionDisplayParams(
                id: session.id, params: params, timeout: 10.0)
        } catch {
            Logger.attachment.error("failed to update running attachment: \(error)")
        }

        // We'll get a notification over the attachment delegate when the
        // session updates.
    }

    func detach() async {
        // No more events.
        self.enableEventPropogation = false

        let _ = await self.setupTask?.result

        let endStatus: AttachmentPresentationStatus
        switch self.status {
        case .errored(_, _), .ended:
            // Do nothing.
            endStatus = self.status
        default:
            self.status = .liveOperation("Closing stream...")
            endStatus = .ended
        }

        if let handle = self.attachment.take() {
            try? await handle.detach()
        }

        self.status = endStatus
    }
}

extension Attachment: AttachmentDelegate {
    nonisolated func videoStreamStart(streamSeq: UInt64, params: MMClientCommon.VideoStreamParams) {
        DispatchQueue.main.sync {
            if !self.enableEventPropogation {
                return
            }

            self.status = .connected
            if let stream = self.videoStream {
                Task { await stream.reset(streamSeq: streamSeq, params: params) }
            } else {
                self.videoStream = VideoStreamReader(
                    player: self.superDelegate.videoPlayer,
                    streamSeq: streamSeq, streamParams: params)
            }
        }
    }

    nonisolated func videoPacket(packet: MMClientCommon.Packet) {
        let pts = packet.pts()
        weak var this = self

        Task {
            await self.videoStream?.recvPacket(packet) {
                // And then after the video frame has been rendered...
                let now = ContinuousClock.now

                Task {
                    if let self = this, await self.enableEventPropogation {
                        await self.superDelegate.audioPlayer.sync(pts: pts, measuredAt: now)
                    }
                }
            }
        }
    }

    nonisolated func droppedVideoPacket(dropped: MMClientCommon.DroppedPacket) {
        if dropped.optional {
            return
        }

        weak var this = self
        Task {
            if let self = this, await self.enableEventPropogation,
                let currentStreamSeq = await self.videoStream?.streamSeq,
                dropped.streamSeq == currentStreamSeq
            {
                await self.attachment?.requestVideoRefresh(streamSeq: currentStreamSeq)
            }
        }
    }

    nonisolated func audioStreamStart(streamSeq: UInt64, params: MMClientCommon.AudioStreamParams) {
        DispatchQueue.main.sync {
            if !self.enableEventPropogation {
                return
            }

            guard
                let stream = OpusAudioStreamReader(
                    player: self.superDelegate.audioPlayer, params: params)
            else {
                Logger.attachment.error("failed to initialize opus audio stream")
                return
            }

            self.superDelegate.audioPlayer.streamStarted(format: stream.format)
            self.audioStream = stream
        }
    }

    nonisolated func audioPacket(packet: MMClientCommon.Packet) {
        Task(priority: .high) { await self.audioStream?.recvPacket(packet) }
    }

    nonisolated func updateCursor(
        icon: MMClientCommon.CursorIcon, image: Data?, hotspotX: UInt32, hotspotY: UInt32
    ) {
        DispatchQueue.main.sync {
            if self.enableEventPropogation {
                var loadedImage: NSImage?
                if let data = image {
                    loadedImage = NSImage(data: data)
                } else {
                    loadedImage = nil
                }

                self.superDelegate.updateCursor(
                    icon: icon, image: loadedImage,
                    hotspot: CGPoint(x: Int(hotspotX), y: Int(hotspotY)))
            }
        }
    }

    nonisolated func lockPointer(x: Double, y: Double) {
        DispatchQueue.main.sync {
            if self.enableEventPropogation {
                self.superDelegate.lockPointer(to: CGPoint(x: x, y: y))
            }
        }
    }

    nonisolated func releasePointer() {
        DispatchQueue.main.sync {
            if self.enableEventPropogation {
                self.superDelegate.releasePointer()
            }
        }
    }

    nonisolated func displayParamsChanged(
        params: MMClientCommon.DisplayParams, reattachRequired: Bool
    ) {
        DispatchQueue.main.sync {
            guard var session = self.session, self.enableEventPropogation else {
                return
            }

            session.displayParams = params
            self.session?.displayParams = params
            self.server.sessions[session.id]?.displayParams = params

            if !reattachRequired {
                self.status = .connected
                return
            }

            self.attachment = nil
            self.parent?.attach(to: self.server, session: session)
        }
    }

    nonisolated func error(err: MMClientCommon.ClientError) {
        DispatchQueue.main.sync {
            self.status = .errored(withClientError: err)
        }
    }

    nonisolated func attachmentEnded() {
        DispatchQueue.main.sync {
            self.attachment = nil
            if case .errored = self.status {
                // Leave the status as what it is.
            } else {
                self.status = .ended
            }

            if self.enableEventPropogation {
                self.superDelegate.didDetach()
            }
        }
    }

}
