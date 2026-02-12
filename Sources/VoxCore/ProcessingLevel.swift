import Foundation

public enum ProcessingLevel: String, Codable, CaseIterable, Sendable {
    case off
    case light
    case aggressive
    case enhance

    /// Single default rewrite model for all processing levels (simplicity > micro-optimizing per-mode).
    public static let defaultRewriteModel = "gemini-2.5-flash-lite"

    public var defaultModel: String {
        switch self {
        case .off:
            return ""
        case .light, .aggressive, .enhance:
            return Self.defaultRewriteModel
        }
    }
}
