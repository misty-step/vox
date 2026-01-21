import Foundation
import VoxCore

enum ProcessingLevelStore {
    private static let key = "vox.processingLevel"

    static func load() -> ProcessingLevel? {
        guard let value = UserDefaults.standard.string(forKey: key) else { return nil }
        return ProcessingLevel(rawValue: value)
    }

    static func save(_ level: ProcessingLevel) {
        UserDefaults.standard.set(level.rawValue, forKey: key)
    }
}
