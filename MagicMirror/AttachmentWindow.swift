import CoreVideoTools
import MMClientCommon
import MetalKit
import OSLog
import SwiftUI
import VideoToolbox

class AttachmentView: MTKView {
    var titleTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingArea = self.titleTrackingArea {
            self.removeTrackingArea(trackingArea)
        }

        self.addTitlebarTrackingArea()
    }

    /// Adds a special tracking area for the title bar.
    func addTitlebarTrackingArea() {
        self.titleTrackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(self.titleTrackingArea!)
    }
}

class AttachmentWindow: NSWindow, NSWindowDelegate {
    fileprivate var overlay: NSVisualEffectView
    fileprivate var overlayContent: NSHostingView<AttachmentOverlay>

    init(view: AttachmentView, overlay: AttachmentOverlay) {
        self.overlay = NSVisualEffectView()
        self.overlayContent = NSHostingView(rootView: overlay)

        let styleMask: StyleMask = [
            .titled, .closable, .miniaturizable, .resizable,
            .fullSizeContentView,
        ]
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        self.delegate = self

        #if DEBUG
            self.backgroundColor = .magenta
        #else
            self.backgroundColor = .black
        #endif

        self.contentView = view
        view.wantsLayer = true

        // Overlay - first blur, then a SwiftUI view with the contents.
        view.addSubview(self.overlay)

        self.overlay.material = .fullScreenUI
        self.overlay.blendingMode = .withinWindow
        self.overlay.state = .active
        self.overlay.wantsLayer = true

        self.overlay.translatesAutoresizingMaskIntoConstraints = false
        self.overlay.setFrameSize(view.frame.size)
        self.overlay.topAnchor.constraint(equalTo: view.topAnchor).isActive =
            true
        self.overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            .isActive = true
        self.overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            .isActive = true
        self.overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            .isActive = true

        self.overlay.addSubview(self.overlayContent)

        self.overlayContent.translatesAutoresizingMaskIntoConstraints = false
        self.overlayContent.setFrameSize(view.frame.size)
        self.overlayContent.topAnchor.constraint(equalTo: view.topAnchor)
            .isActive = true
        self.overlayContent.leadingAnchor.constraint(
            equalTo: view.leadingAnchor
        ).isActive = true
        self.overlayContent.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            .isActive = true
        self.overlayContent.trailingAnchor.constraint(
            equalTo: view.trailingAnchor
        ).isActive = true

        self.isReleasedWhenClosed = true
        self.hidesOnDeactivate = true

        view.addTitlebarTrackingArea()
        self.animateTitleBar(hidden: true)
    }

    func showOverlay(overAttachment: Bool) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.overlay.animator().alphaValue = 1
            self.overlay.animator().isHidden = false
            self.overlay.animator().blendingMode =
                overAttachment ? .withinWindow : .behindWindow
        })
    }

    func hideOverlay() {
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.3
                self.overlay.animator().alphaValue = 0
            },
            completionHandler: {
                self.overlay.isHidden = true
            }
        )
    }

    // Unclear why, but the default behavior is to swallow the event.
    override func rightMouseDown(with event: NSEvent) {
        self.nextResponder?.rightMouseDown(with: event)
    }
}

@MainActor @Observable
class AttachmentWindowController: NSWindowController {
    static let main = AttachmentWindowController()

    let presentation: AttachmentPresentation
    private var decoder: AttachmentDecompressionSession
    private var renderer: AttachmentRenderer
    var audioPlayer = SyncingAudioEngine()

    private var lastConfig: LaunchConfiguration?

    private let gamepadManager = GamepadManager()

    init() {
        let view = AttachmentView()
        let renderer = AttachmentRenderer(view)

        self.renderer = renderer
        self.decoder = AttachmentDecompressionSession(renderer: renderer)
        self.presentation = AttachmentPresentation()

        let window = AttachmentWindow(
            view: view,
            overlay: AttachmentOverlay(presentation: self.presentation)
        )
        super.init(window: window)

        presentation.delegate = self
        window.delegate = self

        window.setFrameAutosaveName("AttachmentWindow")
        if window.makeFirstResponder(self) != true {
            Logger.attachment.error(
                "failed to install AttachmentWindowController as NSResponder"
            )
        }

        self.updateOverlay()
    }

    required init?(coder: NSCoder) {
        fatalError("not implemented")
    }

    var status: AttachmentPresentationStatus {
        self.presentation.status
    }

    /// Launches an app and presents it in the window.
    func launch(
        server: Server,
        applicationID: String,
        config: LaunchConfiguration
    ) {
        self.lastConfig = config

        let gamepads: [Gamepad] =
            if let pad = self.gamepadManager.currentPad {
                [pad]
            } else {
                []
            }

        let params = self.prepareForAttachment(config)
        self.presentation.attach(
            to: server,
            applicationID: applicationID,
            displayParams: params,
            gamepads: gamepads
        )

        self.window?.makeKeyAndOrderFront(nil)
    }

    /// Resizes an existing session and presents it in the window.
    func attach(
        server: Server,
        session: Session,
        config: LaunchConfiguration
    ) {
        self.lastConfig = config

        let params = self.prepareForAttachment(config)
        self.presentation.attach(
            to: server,
            session: session,
            updatedDisplayParams: params
        )
        self.window?.makeKeyAndOrderFront(nil)
    }

    /// Detaches from any running session.
    func detach() {
        self.lastConfig = nil

        if self.status.isSome {
            self.presentation.detach()
            self.window?.close()
            self.audioPlayer.stop()
        }
    }

    /// Reconnects to a running session.
    func refresh() {
        self.presentation.attachWithLastConfiguration()
    }

    private func prepareForAttachment(
        _ config: LaunchConfiguration
    )
        -> DisplayParams
    {
        guard let window = self.window else {
            fatalError("window doesn't exist")
        }

        self.renderer.clear()
        self.presentation.detach()

        let backing: CGSize

        switch config.localDisplayMode {
        case .fullscreen:
            backing =
                NSScreen.main?.attachmentDimensions ?? CGSize(width: 1920, height: 1080)
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        case .windowed:
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }

            let frame = window.frame
            backing = window.screen?.convertRectToBacking(frame).size ?? frame.size
        }

        let (width, height): (UInt32, UInt32) =
            switch config.remoteDisplayConfig {
            case .auto:
                (UInt32(backing.width), UInt32(backing.height))
            case .fixedHeight(let fixedHeight):
                (fixedHeight.calculateWidth(for: backing), UInt32(fixedHeight.rawValue))
            case .customDimensions(let width, let height):
                (width, height)
            }

        let scale =
            if let windowScale = window.screen?.pixelScale, !config.forceRemoteScaleToBe1x {
                windowScale
            } else {
                PixelScale.one
            }

        return DisplayParams(
            width: width,
            height: height,
            framerate: UInt32(config.remoteDisplayFramerate.rawValue),
            uiScale: scale
        )
    }

    func updateOverlay() {
        Logger.attachment.debug(
            "attachment status changed: \(String(describing: self.presentation.status))"
        )

        guard let window = self.window as? AttachmentWindow else {
            return
        }

        withObservationTracking {
            if self.presentation.status.needsOverlay
                && !self.presentation.status.isConnected
            {
                window.showOverlay(overAttachment: false)
            } else if self.presentation.status.needsOverlay {
                window.showOverlay(overAttachment: true)
            } else {
                window.hideOverlay()
            }
        } onChange: {
            DispatchQueue.main.async { self.updateOverlay() }
        }
    }

    private var cursor: NSCursor?
    private var cursorHidden = false

    private var wantsCursorHidden = false
    private var wantsCursorLockedTo: CGPoint?

    private var isMouseOverTexture = false
    private var cursorExplicitlyReleased = false

    private func updateCursor() {
        guard let window = self.window else {
            return
        }

        let cursorCaptured =
            (self.isMouseOverTexture
                && !self.cursorExplicitlyReleased
                && (window.isKeyWindow || window.styleMask.contains(.fullScreen)))
        if cursorCaptured && self.wantsCursorHidden {
            if !self.cursorHidden {
                Logger.attachment.debug("hiding cursor")

                NSCursor.hide()
                self.cursorHidden = true
            }
        } else if self.cursorHidden {
            Logger.attachment.debug("unhiding cursor")

            NSCursor.unhide()
            self.cursorHidden = false
        }

        if cursorCaptured, let coords = self.wantsCursorLockedTo, let window = self.window {
            // The windowCoords use the bottom-left corner as the origin, to be
            // consistent with AppKit and Cocoa. But CGWarpMouseCursorPosition
            // expects coordinates with the origin in the top-left.
            let screenCoords = CGPoint(
                x: window.frame.origin.x + coords.x,
                y: (NSScreen.main!.frame.maxY - window.frame.maxY)
                    + (window.frame.height - coords.y))

            Logger.attachment.debug(
                "locking pointer to \(coords.x)x\(coords.y) (global coords: \(screenCoords.x)x\(screenCoords.y))"
            )

            CGAssociateMouseAndMouseCursorPosition(0)
            CGWarpMouseCursorPosition(screenCoords)

            // TODO: flash message with key combo to unlock
        } else {
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }

    func releaseCursor() {
        self.cursorExplicitlyReleased = true
        self.updateCursor()
    }

    // NSResponder

    override func mouseEntered(with event: NSEvent) {
        self.presentation.handle?.pointerEntered()

        guard let window = self.window as? AttachmentWindow,
            let view = window.contentView as? AttachmentView,
            let renderer = view.delegate as? AttachmentRenderer
        else {
            return
        }

        if event.locationInWindow.y <= (view.bounds.height - window.titleBarHeight),
            renderer.convertToTextureCoords(from: event.locationInWindow) != nil
        {
            self.isMouseOverTexture = true
        }

        self.updateCursor()
    }

    override func mouseExited(with event: NSEvent) {
        self.presentation.handle?.pointerLeft()
        self.isMouseOverTexture = false
        self.updateCursor()
    }

    override func mouseMoved(with event: NSEvent) {
        // If the cursor was explicitly released, we shouldn't send any mouse input.
        if self.cursorExplicitlyReleased {
            return
        }

        guard let window = self.window as? AttachmentWindow,
            let view = self.window?.contentView as? AttachmentView,
            let renderer = view.delegate as? AttachmentRenderer
        else {
            return
        }

        // Animate the title bar in and out.
        let hideTitleBar = event.locationInWindow.y <= (view.bounds.height - window.titleBarHeight)
        window.animateTitleBar(hidden: hideTitleBar)

        guard let handle = self.presentation.handle,
            let config = self.presentation.config
        else {
            return
        }

        let coords = renderer.convertToTextureCoords(from: event.locationInWindow)
        if let uv = coords {
            handle.pointerMotion(
                x: uv.x * Double(config.width),
                y: uv.y * Double(config.height)
            )
        }

        let wasMouseOverTexture = self.isMouseOverTexture

        // Don't consider the mouse actually entered if it's over the titlebar.
        if coords != nil && (hideTitleBar || self.wantsCursorLockedTo != nil) {
            self.isMouseOverTexture = true
        } else {
            self.isMouseOverTexture = false
        }

        if self.isMouseOverTexture != wasMouseOverTexture {
            self.updateCursor()
        }

        let (relX, relY) = renderer.convertToTextureVector(from: (event.deltaX, event.deltaY))
        handle.relativePointerMotion(
            x: relX * Double(config.width), y: relY * Double(config.height))
    }

    override func mouseDragged(with event: NSEvent) {
        self.mouseMoved(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        self.mouseMoved(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if self.cursorExplicitlyReleased {
            self.cursorExplicitlyReleased = false
            self.updateCursor()
            return
        }

        self.mouseButtonEvent(
            locationInWindow: event.locationInWindow,
            button: .left,
            state: .pressed
        )
    }

    override func mouseUp(with event: NSEvent) {
        self.mouseButtonEvent(
            locationInWindow: event.locationInWindow,
            button: .left,
            state: .released
        )
    }

    override func rightMouseDown(with event: NSEvent) {
        self.mouseButtonEvent(
            locationInWindow: event.locationInWindow,
            button: .right,
            state: .pressed
        )
    }

    override func rightMouseUp(with event: NSEvent) {
        self.mouseButtonEvent(
            locationInWindow: event.locationInWindow,
            button: .right,
            state: .released
        )
    }

    func mouseButtonEvent(
        locationInWindow: CGPoint,
        button: MMClientCommon.Button,
        state: MMClientCommon.ButtonState
    ) {
        // If the cursor was explicitly released, we shouldn't send any mouse input.
        if self.cursorExplicitlyReleased {
            return
        }

        if let view = self.window?.contentView as? AttachmentView,
            let renderer = view.delegate as? AttachmentRenderer,
            let uv = renderer.convertToTextureCoords(from: locationInWindow),
            let config = self.presentation.config
        {
            self.presentation.handle?.pointerInput(
                button: button,
                state: state,
                x: uv.x * Double(config.width),
                y: uv.y * Double(config.height)
            )
        }
    }

    override func keyDown(with event: NSEvent) {
        self.keyEvent(event, state: event.isARepeat ? KeyState.repeat : KeyState.pressed)
    }

    override func keyUp(with event: NSEvent) {
        self.keyEvent(event, state: .released)
    }

    func keyEvent(_ event: NSEvent, state: MMClientCommon.KeyState) {
        if let key = Key(scancode: event.keyCode) {
            var character: UInt32 = 0
            if key.usedForTextInput, let s = event.characters, s.count > 0 {
                character = UInt32(s.unicodeScalars.first!)
            }

            self.presentation.handle?.keyboardInput(
                key: key, state: state, character: character)
        } else {
            Logger.attachment.error(
                "unrecognized keyCode: \(event.keyCode) (characters: \(String(describing: event.characters))"
            )
        }
    }

    var shiftPressed: Bool = false
    var controlPressed: Bool = false
    var altPressed: Bool = false
    var commandPressed: Bool = false
    var fnPressed: Bool = false

    override func flagsChanged(with event: NSEvent) {
        let modifiers = NSEvent.modifierFlags.intersection(
            NSEvent.ModifierFlags.deviceIndependentFlagsMask)

        guard let handle = self.presentation.handle else {
            return
        }

        if !self.shiftPressed && modifiers.contains(.shift) {
            handle.keyboardInput(key: .shiftLeft, state: .pressed, character: 0)
            self.shiftPressed = true
        } else if self.shiftPressed && !modifiers.contains(.shift) {
            handle.keyboardInput(key: .shiftLeft, state: .released, character: 0)
            self.shiftPressed = false
        }

        if !self.controlPressed && modifiers.contains(.control) {
            handle.keyboardInput(key: .controlLeft, state: .pressed, character: 0)
            self.controlPressed = true
        } else if self.controlPressed && !modifiers.contains(.control) {
            handle.keyboardInput(key: .controlLeft, state: .released, character: 0)
            self.controlPressed = false
        }

        if !self.altPressed && modifiers.contains(.option) {
            handle.keyboardInput(key: .altLeft, state: .pressed, character: 0)
            self.altPressed = true
        } else if self.altPressed && !modifiers.contains(.option) {
            handle.keyboardInput(key: .altLeft, state: .released, character: 0)
            self.altPressed = false
        }

        if !self.commandPressed && modifiers.contains(.command) {
            handle.keyboardInput(key: .metaLeft, state: .pressed, character: 0)
            self.commandPressed = true
        } else if self.commandPressed && !modifiers.contains(.command) {
            handle.keyboardInput(key: .metaLeft, state: .released, character: 0)
            self.commandPressed = false
        }

    }
}

extension AttachmentWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        self.presentation.detach()
        self.renderer.clear()
        self.audioPlayer.stop()

        self.wantsCursorHidden = false
        self.wantsCursorLockedTo = nil
        self.cursorExplicitlyReleased = false
        self.updateCursor()

        // For the next open.
        (self.window as? AttachmentWindow)?.showOverlay(overAttachment: false)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        self.updateCursor()
    }

    func windowDidResignKey(_ notification: Notification) {
        self.updateCursor()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        self.updateCursor()

        guard let window = self.window, let config = self.lastConfig else {
            return
        }

        Logger.attachment.debug("performing live resize")

        let backing =
            window.screen?.convertRectToBacking(window.frame) ?? window.frame

        let scale =
            if let windowScale = window.screen?.pixelScale, !config.forceRemoteScaleToBe1x {
                windowScale
            } else {
                PixelScale.one
            }

        let (width, height): (UInt32, UInt32) =
            switch config.remoteDisplayConfig {
            case .auto:
                (UInt32(backing.width), UInt32(backing.height))
            case .fixedHeight(let fixedHeight):
                (fixedHeight.calculateWidth(for: backing.size), UInt32(fixedHeight.rawValue))
            case .customDimensions(let width, let height):
                (width, height)
            }

        let params = DisplayParams(
            width: width,
            height: height,
            framerate: UInt32(config.remoteDisplayFramerate.rawValue),
            uiScale: scale
        )

        self.presentation.updateDisplayParamsLive(with: params)
    }
}

extension AttachmentWindowController: AttachmentPresentationDelegate {
    var videoPlayer: AttachmentDecompressionSession {
        self.decoder
    }

    func didAttach(_ attachment: Attachment) {
        self.gamepadManager.enableInputFor(attachment: attachment)
    }

    func updateCursor(
        icon: MMClientCommon.CursorIcon,
        image: NSImage?,
        hotspot: CGPoint
    ) {
        if let image = image {
            self.cursor = NSCursor(image: image, hotSpot: hotspot)
            self.cursor!.set()
        } else {
            self.cursor = nil

            switch icon {
            case .none:
                self.wantsCursorHidden = true
                self.updateCursor()

                return
            case .contextMenu:
                NSCursor.contextualMenu.set()
            case .pointer:
                NSCursor.pointingHand.set()
            case .crosshair:
                NSCursor.crosshair.set()
            case .text:
                NSCursor.iBeam.set()
            case .verticalText:
                NSCursor.iBeamCursorForVerticalLayout.set()
            case .copy:
                NSCursor.dragCopy.set()
            case .notAllowed:
                NSCursor.operationNotAllowed.set()
            case .grab:
                NSCursor.openHand.set()
            case .grabbing:
                NSCursor.closedHand.set()
            case .eResize:
                NSCursor.resizeRight.set()
            case .wResize:
                NSCursor.resizeLeft.set()
            case .nResize:
                NSCursor.resizeUp.set()
            case .sResize:
                NSCursor.resizeDown.set()
            case .ewResize:
                NSCursor.resizeLeftRight.set()
            case .nsResize:
                NSCursor.resizeUpDown.set()
            case .neResize, .swResize, .neswResize:
                if #available(macOS 15.0, *) {
                    NSCursor.frameResize(position: .topRight, directions: .all)
                        .set()
                }
            case .nwResize, .seResize, .nwseResize:
                if #available(macOS 15.0, *) {
                    NSCursor.frameResize(position: .topLeft, directions: .all)
                        .set()
                }
            case .colResize:
                if #available(macOS 15.0, *) {
                    NSCursor.columnResize.set()
                } else {
                    NSCursor.resizeLeftRight.set()
                }
            case .rowResize:
                if #available(macOS 15.0, *) {
                    NSCursor.rowResize.set()
                } else {
                    NSCursor.resizeUpDown.set()
                }
            case .zoomIn:
                if #available(macOS 15.0, *) {
                    NSCursor.zoomIn.set()
                }
            case .zoomOut:
                if #available(macOS 15.0, *) {
                    NSCursor.zoomOut.set()
                }
            default:
                NSCursor.arrow.set()
            }
        }

        // Whatever it is, show the cursor.
        self.wantsCursorHidden = false
        self.updateCursor()
    }

    func lockPointer(to location: CGPoint) {
        if let view = self.window?.contentView as? AttachmentView,
            let renderer = view.delegate as? AttachmentRenderer,
            let config = self.presentation.config
        {
            let textureCoords = CGPoint(
                x: location.x / Double(config.width),
                y: location.y / Double(config.height)
            )

            let windowCoords = view.convert(
                renderer.convertToViewCoords(from: textureCoords), to: nil)
            self.wantsCursorLockedTo = windowCoords
            self.updateCursor()
        }
    }

    func releasePointer() {
        self.wantsCursorLockedTo = nil
        self.updateCursor()
    }
}

extension NSWindow {
    func setFrameSize(size: CGSize) {
        var frame = self.frame
        frame.origin.x += (frame.width - size.width) / 2
        frame.origin.y += (frame.height - size.height) / 2
        frame.size = size

        self.setFrame(frame, display: true, animate: true)
    }

    func animateTitleBar(hidden: Bool) {
        guard let view = standardWindowButton(.zoomButton)?.superview?.superview
        else {
            return
        }

        if hidden && !self.styleMask.contains(.fullScreen) {
            view.animator().alphaValue = 0
        } else {
            view.animator().alphaValue = 1
        }
    }

    var titleBarHeight: CGFloat {
        standardWindowButton(.zoomButton)?.superview?.superview?.bounds.height
            ?? 100.0
    }
}
