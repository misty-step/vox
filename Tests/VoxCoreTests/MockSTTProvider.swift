import Foundation
@testable import VoxCore

final class MockSTTProvider: STTProvider, @unchecked Sendable {
    var results: [Result<String, Error>]
    var callCount = 0

    init(results: [Result<String, Error>] = []) {
        self.results = results
    }

    func transcribe(audioURL: URL) async throws -> String {
        let index = callCount
        callCount += 1
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
