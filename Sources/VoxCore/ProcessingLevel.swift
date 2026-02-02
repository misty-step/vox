import Foundation

public enum ProcessingLevel: String, Codable, CaseIterable, Sendable {
    case off
    case light
    case aggressive
    case enhance

    public var defaultModel: String {
        switch self {
        case .off:        return ""
        case .light:      return "google/gemini-2.5-flash-lite"
        case .aggressive: return "google/gemini-2.5-flash"
        case .enhance:    return "deepseek/deepseek-v3.2"
        }
    }
}
