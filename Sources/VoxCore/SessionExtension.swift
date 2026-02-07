import Foundation

public struct DictationUsageEvent: Sendable, Equatable {
    public let recordingDuration: TimeInterval
    public let outputCharacterCount: Int
    public let processingLevel: ProcessingLevel

    public init(
        recordingDuration: TimeInterval,
        outputCharacterCount: Int,
        processingLevel: ProcessingLevel
    ) {
        self.recordingDuration = recordingDuration
        self.outputCharacterCount = max(outputCharacterCount, 0)
        self.processingLevel = processingLevel
    }
}

@MainActor
public protocol SessionExtension: AnyObject {
    func authorizeRecordingStart() async throws
    func didCompleteDictation(event: DictationUsageEvent) async
    func didFailDictation(reason: String) async
}

extension SessionExtension {
    public func authorizeRecordingStart() async throws {}
    public func didCompleteDictation(event: DictationUsageEvent) async {}
    public func didFailDictation(reason: String) async {}
}

@MainActor
public final class NoopSessionExtension: SessionExtension {
    public init() {}
}
