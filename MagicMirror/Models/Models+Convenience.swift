import Carbon.HIToolbox.Events
import Foundation
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

// TODO: use https://github.com/ChimeHQ/KeyCodes to make this UIKey-compatible
extension MMClientCommon.Key {
    init?(scancode: UInt16) {
        switch Int(scancode) {
        case kVK_ANSI_A:
            self = .a
        case kVK_ANSI_S:
            self = .s
        case kVK_ANSI_D:
            self = .d
        case kVK_ANSI_F:
            self = .f
        case kVK_ANSI_H:
            self = .h
        case kVK_ANSI_G:
            self = .g
        case kVK_ANSI_Z:
            self = .z
        case kVK_ANSI_X:
            self = .x
        case kVK_ANSI_C:
            self = .c
        case kVK_ANSI_V:
            self = .v
        case kVK_ANSI_B:
            self = .b
        case kVK_ANSI_Q:
            self = .q
        case kVK_ANSI_W:
            self = .w
        case kVK_ANSI_E:
            self = .e
        case kVK_ANSI_R:
            self = .r
        case kVK_ANSI_Y:
            self = .y
        case kVK_ANSI_T:
            self = .t
        case kVK_ANSI_1:
            self = .digit1
        case kVK_ANSI_2:
            self = .digit2
        case kVK_ANSI_3:
            self = .digit3
        case kVK_ANSI_4:
            self = .digit4
        case kVK_ANSI_6:
            self = .digit6
        case kVK_ANSI_5:
            self = .digit5
        case kVK_ANSI_Equal:
            self = .equal
        case kVK_ANSI_9:
            self = .digit9
        case kVK_ANSI_7:
            self = .digit7
        case kVK_ANSI_Minus:
            self = .minus
        case kVK_ANSI_8:
            self = .digit8
        case kVK_ANSI_0:
            self = .digit0
        case kVK_ANSI_RightBracket:
            self = .bracketRight
        case kVK_ANSI_O:
            self = .o
        case kVK_ANSI_U:
            self = .u
        case kVK_ANSI_LeftBracket:
            self = .bracketLeft
        case kVK_ANSI_I:
            self = .i
        case kVK_ANSI_P:
            self = .p
        case kVK_ANSI_L:
            self = .l
        case kVK_ANSI_J:
            self = .j
        case kVK_ANSI_Quote:
            self = .quote
        case kVK_ANSI_K:
            self = .k
        case kVK_ANSI_Semicolon:
            self = .semicolon
        case kVK_ANSI_Backslash:
            self = .backslash
        case kVK_ANSI_Comma:
            self = .comma
        case kVK_ANSI_Slash:
            self = .slash
        case kVK_ANSI_N:
            self = .n
        case kVK_ANSI_M:
            self = .m
        case kVK_ANSI_Period:
            self = .period
        case kVK_ANSI_Grave:
            self = .backquote
        case kVK_ANSI_KeypadDecimal:
            self = .numpadDecimal
        case kVK_ANSI_KeypadMultiply:
            self = .numpadMultiply
        case kVK_ANSI_KeypadPlus:
            self = .numpadAdd
        case kVK_ANSI_KeypadClear:
            self = .numpadClear
        case kVK_ANSI_KeypadDivide:
            self = .numpadDivide
        case kVK_ANSI_KeypadEnter:
            self = .numpadEnter
        case kVK_ANSI_KeypadMinus:
            self = .numpadSubtract
        case kVK_ANSI_KeypadEquals:
            self = .numpadEqual
        case kVK_ANSI_Keypad0:
            self = .numpad0
        case kVK_ANSI_Keypad1:
            self = .numpad1
        case kVK_ANSI_Keypad2:
            self = .numpad2
        case kVK_ANSI_Keypad3:
            self = .numpad3
        case kVK_ANSI_Keypad4:
            self = .numpad4
        case kVK_ANSI_Keypad5:
            self = .numpad5
        case kVK_ANSI_Keypad6:
            self = .numpad6
        case kVK_ANSI_Keypad7:
            self = .numpad7
        case kVK_ANSI_Keypad8:
            self = .numpad8
        case kVK_ANSI_Keypad9:
            self = .numpad9
        case kVK_Return:
            self = .enter
        case kVK_Tab:
            self = .tab
        case kVK_Space:
            self = .space
        case kVK_Delete:
            self = .backspace
        case kVK_Escape:
            self = .escape
        case kVK_Command:
            self = .metaLeft
        case kVK_Shift:
            self = .shiftLeft
        case kVK_CapsLock:
            self = .capsLock
        case kVK_Option:
            self = .altLeft
        case kVK_Control:
            self = .controlLeft
        case kVK_RightCommand:
            self = .metaRight
        case kVK_RightShift:
            self = .shiftRight
        case kVK_RightOption:
            self = .altRight
        case kVK_RightControl:
            self = .controlRight
        case kVK_Function:
            self = .fn
        case kVK_F17:
            return nil
        case kVK_VolumeUp:
            return nil
        case kVK_VolumeDown:
            return nil
        case kVK_Mute:
            return nil
        case kVK_F18:
            return nil
        case kVK_F19:
            return nil
        case kVK_F20:
            return nil
        case kVK_F5:
            self = .f5
        case kVK_F6:
            self = .f6
        case kVK_F7:
            self = .f7
        case kVK_F3:
            self = .f3
        case kVK_F8:
            self = .f8
        case kVK_F9:
            self = .f9
        case kVK_F11:
            self = .f11
        case kVK_F13:
            return nil
        case kVK_F16:
            return nil
        case kVK_F14:
            return nil
        case kVK_F10:
            self = .f10
        case kVK_ContextualMenu:
            self = .contextMenu
        case kVK_F12:
            self = .f12
        case kVK_F15:
            return nil
        case kVK_Help:
            self = .help
        case kVK_Home:
            self = .home
        case kVK_PageUp:
            self = .pageUp
        case kVK_ForwardDelete:
            self = .delete
        case kVK_F4:
            self = .f4
        case kVK_End:
            self = .end
        case kVK_F2:
            self = .f2
        case kVK_PageDown:
            self = .pageDown
        case kVK_F1:
            self = .f1
        case kVK_LeftArrow:
            self = .arrowLeft
        case kVK_RightArrow:
            self = .arrowRight
        case kVK_DownArrow:
            self = .arrowDown
        case kVK_UpArrow:
            self = .arrowUp
        case kVK_ISO_Section:
            return nil  // ?
        case kVK_JIS_Yen:
            self = .intlYen
        case kVK_JIS_Underscore:
            return nil  // ?
        case kVK_JIS_KeypadComma:
            self = .numpadComma
        case kVK_JIS_Eisu:
            self = .lang2
        case kVK_JIS_Kana:
            self = .lang1
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
