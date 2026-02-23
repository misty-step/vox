import Foundation

public enum ProcessingLevel: String, Codable, CaseIterable, Sendable {
    case raw
    case clean
    case polish

    public init?(rawValue: String) {
        switch rawValue {
        case "raw", "off":
            self = .raw
        case "clean", "light", "enhance":
            self = .clean
        case "polish", "aggressive":
            self = .polish
        default:
            return nil
        }
    }

    /// Default rewrite model for Clean.
    /// Keep centralized so rollback is a one-file change.
    public static let defaultCleanRewriteModel = "gemini-2.5-flash-lite"

    /// Default rewrite model for Polish.
    /// Same model as Clean — gemini-2.5-flash-lite wins on latency and quality for both levels.
    /// See docs/performance/rewrite-model-lockdown-2026-02-23.md for bakeoff evidence.
    public static let defaultPolishRewriteModel = "gemini-2.5-flash-lite"

    public var defaultModel: String {
        switch self {
        case .raw:
            return ""
        case .clean:
            return Self.defaultCleanRewriteModel
        case .polish:
            return Self.defaultPolishRewriteModel
        }
    }
}
