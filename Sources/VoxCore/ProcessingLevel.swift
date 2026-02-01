import Foundation

public enum ProcessingLevel: String, Codable, CaseIterable, Sendable {
    case off
    case light
    case aggressive
    case enhance
}
