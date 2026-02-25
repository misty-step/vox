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
    public static let defaultCleanRewriteModel = "inception/mercury"

    /// Default rewrite model for Polish.
    /// Same model as Clean.
    public static let defaultPolishRewriteModel = "inception/mercury"

    /// Gemini model used for best-effort fallback when an OpenRouter-only model is requested
    /// but OpenRouter is unavailable and Gemini is configured.
    public static let defaultGeminiFallbackModel = "gemini-2.5-flash-lite"

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
