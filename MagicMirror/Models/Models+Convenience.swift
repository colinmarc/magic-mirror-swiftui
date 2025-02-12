import Foundation
import KeyCodes
import MMClientCommon

extension AttachmentConfig {
    init(
        width: UInt32, height: UInt32, codec: VideoCodec = .h265, profile: VideoProfile = .hd,
        qualityPreset: UInt32? = .none, videoStreamSeqOffset: UInt64 = 0,
        audioStreamSeqOffset: UInt64 = 0
    ) {
        self.init(
            width: width, height: height, videoCodec: codec, videoProfile: profile,
            qualityPreset: qualityPreset, audioCodec: .none, sampleRate: .none, channels: [],
            videoStreamSeqOffset: videoStreamSeqOffset, audioStreamSeqOffset: audioStreamSeqOffset)
    }
}

extension Application {
    var appPath: String {
        self.folder.joined(separator: "/")
    }

    var parentFolder: String? {
        self.folder.last
    }

    var headerImageAvailable: Bool {
        self.imagesAvailable.contains(.header)
    }

    var displayName: String {
        if self.description != "" {
            return self.description
        } else {
            return self.id
        }
    }
}

extension PixelScale {
    static var one = Self.init(numerator: 1, denominator: 1)
}

extension VideoCodec: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .av1:
            "AV1"
        case .h264:
            "H264"
        case .h265:
            "H265"
        case .unknown:
            "UNKNOWN"
        }
    }
}

#if os(macOS)
    import Carbon.HIToolbox.Events
#endif

// TODO: use https://github.com/ChimeHQ/KeyCodes to make this UIKey-compatible
extension MMClientCommon.Key {
    init?(from keycode: KeyCodes.KeyboardHIDUsage?, with scancode: UInt16? = nil) {
        #if os(macOS)
            if let scancode {
                switch Int(scancode) {
                case kVK_JIS_Yen:
                    self = .intlYen
                    return
                case kVK_JIS_Underscore:
                    return nil  // ?
                case kVK_JIS_Eisu:
                    self = .lang2
                    return
                case kVK_JIS_Kana:
                    self = .lang1
                    return
                case kVK_Command:
                    self = .metaLeft
                    return
                case kVK_RightCommand:
                    self = .metaRight
                    return
                case kVK_Function:
                    self = .fn
                    return
                default:
                    break
                }
            }
        #endif

        switch keycode {
        case .keyboardA:
            self = .a
        case .keyboardS:
            self = .s
        case .keyboardD:
            self = .d
        case .keyboardF:
            self = .f
        case .keyboardH:
            self = .h
        case .keyboardG:
            self = .g
        case .keyboardZ:
            self = .z
        case .keyboardX:
            self = .x
        case .keyboardC:
            self = .c
        case .keyboardV:
            self = .v
        case .keyboardB:
            self = .b
        case .keyboardQ:
            self = .q
        case .keyboardW:
            self = .w
        case .keyboardE:
            self = .e
        case .keyboardR:
            self = .r
        case .keyboardY:
            self = .y
        case .keyboardT:
            self = .t
        case .keyboard1:
            self = .digit1
        case .keyboard2:
            self = .digit2
        case .keyboard3:
            self = .digit3
        case .keyboard4:
            self = .digit4
        case .keyboard6:
            self = .digit6
        case .keyboard5:
            self = .digit5
        case .keyboardEqualSign:
            self = .equal
        case .keyboard9:
            self = .digit9
        case .keyboard7:
            self = .digit7
        case .keyboardHyphen:
            self = .minus
        case .keyboard8:
            self = .digit8
        case .keyboard0:
            self = .digit0
        case .keyboardCloseBracket:
            self = .bracketRight
        case .keyboardO:
            self = .o
        case .keyboardU:
            self = .u
        case .keyboardOpenBracket:
            self = .bracketLeft
        case .keyboardI:
            self = .i
        case .keyboardP:
            self = .p
        case .keyboardL:
            self = .l
        case .keyboardJ:
            self = .j
        case .keyboardQuote:
            self = .quote
        case .keyboardK:
            self = .k
        case .keyboardSemicolon:
            self = .semicolon
        case .keyboardBackslash:
            self = .backslash
        case .keyboardComma:
            self = .comma
        case .keyboardSlash:
            self = .slash
        case .keyboardN:
            self = .n
        case .keyboardM:
            self = .m
        case .keyboardPeriod:
            self = .period
        case .keyboardGraveAccentAndTilde:
            self = .backquote
        case .keypadPeriod:
            self = .numpadDecimal
        case .keypadAsterisk:
            self = .numpadMultiply
        case .keypadPlus:
            self = .numpadAdd
        case .keypadSlash:
            self = .numpadDivide
        case .keypadEnter:
            self = .numpadEnter
        case .keypadHyphen:
            self = .numpadSubtract
        case .keypadEqualSign:
            self = .numpadEqual
        case .keypad0:
            self = .numpad0
        case .keypad1:
            self = .numpad1
        case .keypad2:
            self = .numpad2
        case .keypad3:
            self = .numpad3
        case .keypad4:
            self = .numpad4
        case .keypad5:
            self = .numpad5
        case .keypad6:
            self = .numpad6
        case .keypad7:
            self = .numpad7
        case .keypad8:
            self = .numpad8
        case .keypad9:
            self = .numpad9
        case .keyboardReturn:
            self = .enter
        case .keyboardTab:
            self = .tab
        case .keyboardSpacebar:
            self = .space
        case .keyboardDeleteOrBackspace:
            self = .backspace
        case .keyboardEscape:
            self = .escape
        case .keyboardLeftShift:
            self = .shiftLeft
        case .keyboardCapsLock:
            self = .capsLock
        case .keyboardLeftAlt:
            self = .altLeft
        case .keyboardLeftControl:
            self = .controlLeft
        case .keyboardRightShift:
            self = .shiftRight
        case .keyboardRightAlt:
            self = .altRight
        case .keyboardRightControl:
            self = .controlRight
        case .keyboardF17:
            return nil
        case .keyboardVolumeUp:
            return nil
        case .keyboardVolumeDown:
            return nil
        case .keyboardMute:
            return nil
        case .keyboardF18:
            return nil
        case .keyboardF19:
            return nil
        case .keyboardF20:
            return nil
        case .keyboardF5:
            self = .f5
        case .keyboardF6:
            self = .f6
        case .keyboardF7:
            self = .f7
        case .keyboardF3:
            self = .f3
        case .keyboardF8:
            self = .f8
        case .keyboardF9:
            self = .f9
        case .keyboardF11:
            self = .f11
        case .keyboardF13:
            return nil
        case .keyboardF16:
            return nil
        case .keyboardF14:
            return nil
        case .keyboardF10:
            self = .f10
        case .keyboardMenu:
            self = .contextMenu
        case .keyboardF12:
            self = .f12
        case .keyboardF15:
            return nil
        case .keyboardHelp:
            self = .help
        case .keyboardHome:
            self = .home
        case .keyboardPageUp:
            self = .pageUp
        case .keyboardDeleteForward:
            self = .delete
        case .keyboardF4:
            self = .f4
        case .keyboardEnd:
            self = .end
        case .keyboardF2:
            self = .f2
        case .keyboardPageDown:
            self = .pageDown
        case .keyboardF1:
            self = .f1
        case .keyboardLeftArrow:
            self = .arrowLeft
        case .keyboardRightArrow:
            self = .arrowRight
        case .keyboardDownArrow:
            self = .arrowDown
        case .keyboardUpArrow:
            self = .arrowUp
        case .keypadComma:
            self = .numpadComma
        default:
            return nil
        }
    }

    /// Returns false if the key is a modifier key of some kind. By default,
    /// the NSEvent for those keys sometimes includes control codes, like ^[ for escape.
    var usedForTextInput: Bool {
        return ![
            .escape, .enter, .numpadEnter, .backspace, .delete,
            .capsLock, .printScreen, .insert, .end, .contextMenu,
            .controlLeft, .controlRight,
            .altLeft, .altRight,
            .metaLeft, .metaRight,
            .pageUp, .pageDown,
        ].contains(self)
    }
}
