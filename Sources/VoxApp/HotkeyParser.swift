import Carbon
import Foundation

enum HotkeyParser {
    static func modifiers(from strings: [String]) -> UInt32 {
        strings.reduce(0) { partial, value in
            switch value.lowercased() {
            case "option", "alt":
                return partial | UInt32(optionKey)
            case "shift":
                return partial | UInt32(shiftKey)
            case "control", "ctrl":
                return partial | UInt32(controlKey)
            case "command", "cmd":
                return partial | UInt32(cmdKey)
            default:
                return partial
            }
        }
    }
}
