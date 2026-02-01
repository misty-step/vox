import Foundation
@testable import VoxCore

final class MockSTTProvider: STTProvider, @unchecked Sendable {
    private let lock = NSLock()
    var results: [Result<String, Error>]
    private var _callCount = 0
    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    init(results: [Result<String, Error>] = []) {
        self.results = results
    }

    func transcribe(audioURL: URL) async throws -> String {
        lock.lock()
        let index = _callCount
        _callCount += 1
        lock.unlock()

        guard index < results.count else {
            throw STTError.unknown("No more mock results")
        }
        switch results[index] {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}
