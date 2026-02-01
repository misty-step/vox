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
        guard index < results.count else {
            lock.unlock()
            throw STTError.unknown("No more mock results")
        }
        let result = results[index]
        lock.unlock()

        switch result {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}
