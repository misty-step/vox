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
    /// Intentionally separate from Clean; polish can trade speed for quality.
    public static let defaultPolishRewriteModel = "x-ai/grok-4.1-fast"

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
