import VoxLocalCore

public enum RewritePrompts {
    public static func prompt(for level: ProcessingLevel) -> String {
        switch level {
        case .off: return ""
        case .light: return "Fix punctuation, capitalization, and remove filler words. Preserve meaning exactly."
        case .aggressive: return "Clarify and improve this dictation for professional communication. You may reorder sentences for clarity, but preserve all key points."
        }
    }
}
