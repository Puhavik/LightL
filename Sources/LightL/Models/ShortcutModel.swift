import Foundation
import Carbon

public struct ShortcutModel: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Default shortcuts:
    // Translate: Option + Command + C (0x08 = 'C', cmdKey | optionKey)
    public static let defaultTranslate = ShortcutModel(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(cmdKey | optionKey)
    )

    // Rewrite / Proofread: Option + Command + W (0x0D = 'W', cmdKey | optionKey)
    public static let defaultRewrite = ShortcutModel(
        keyCode: UInt32(kVK_ANSI_W),
        modifiers: UInt32(cmdKey | optionKey)
    )

    public var displayString: String {
        return keyGlyphs.joined()
    }

    public var keyGlyphs: [String] {
        var glyphs: [String] = []
        if (modifiers & UInt32(controlKey)) != 0 { glyphs.append("⌃") }
        if (modifiers & UInt32(optionKey)) != 0 { glyphs.append("⌥") }
        if (modifiers & UInt32(shiftKey)) != 0 { glyphs.append("⇧") }
        if (modifiers & UInt32(cmdKey)) != 0 { glyphs.append("⌘") }
        let name = keyName(for: Int(keyCode))
        if !name.isEmpty { glyphs.append(name) }
        return glyphs
    }

    private func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "⏎"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        default: return "Key(\(keyCode))"
        }
    }
}
