import Foundation

struct StreamingFinalizationTimeoutPolicy: Sendable, Equatable {
    let baseSeconds: TimeInterval
    let secondsPerAudioSecond: TimeInterval
    let maxSeconds: TimeInterval

    init(
        baseSeconds: TimeInterval,
        secondsPerAudioSecond: TimeInterval,
        maxSeconds: TimeInterval
    ) {
        let sanitizedBase = (baseSeconds.isFinite && baseSeconds > 0) ? baseSeconds : 5.0
        let sanitizedSlope = (secondsPerAudioSecond.isFinite && secondsPerAudioSecond >= 0) ? secondsPerAudioSecond : 0
        let sanitizedMax = (maxSeconds.isFinite && maxSeconds > 0) ? maxSeconds : sanitizedBase

        self.baseSeconds = sanitizedBase
        self.secondsPerAudioSecond = sanitizedSlope
        self.maxSeconds = max(sanitizedBase, sanitizedMax)
    }

    func timeoutSeconds(forStreamedAudioSeconds seconds: TimeInterval) -> TimeInterval {
        let audioSeconds = (seconds.isFinite && seconds > 0) ? seconds : 0
        let proposed = baseSeconds + (audioSeconds * secondsPerAudioSecond)
        guard proposed.isFinite, proposed > 0 else {
            return baseSeconds
        }
        return min(proposed, maxSeconds)
    }

    static let `default` = StreamingFinalizationTimeoutPolicy(
        baseSeconds: 8.0,
        secondsPerAudioSecond: 0.05,
        maxSeconds: 20.0
    )

    static func constant(_ seconds: TimeInterval) -> StreamingFinalizationTimeoutPolicy {
        StreamingFinalizationTimeoutPolicy(
            baseSeconds: seconds,
            secondsPerAudioSecond: 0,
            maxSeconds: seconds
        )
    }
}
