import XCTest
@testable import VoxProviders

final class StreamingFinalizationTimeoutPolicyTests: XCTestCase {
    func test_constantPolicy_returnsConstant() {
        let policy = StreamingFinalizationTimeoutPolicy.constant(0.25)

        XCTAssertEqual(policy.timeoutSeconds(forStreamedAudioSeconds: 0), 0.25, accuracy: 0.0001)
        XCTAssertEqual(policy.timeoutSeconds(forStreamedAudioSeconds: 10), 0.25, accuracy: 0.0001)
    }

    func test_scaledPolicy_increasesWithAudioSeconds_andCaps() {
        let policy = StreamingFinalizationTimeoutPolicy(
            baseSeconds: 5.0,
            secondsPerAudioSecond: 0.1,
            maxSeconds: 12.0
        )

        XCTAssertEqual(policy.timeoutSeconds(forStreamedAudioSeconds: 0), 5.0, accuracy: 0.0001)
        XCTAssertEqual(policy.timeoutSeconds(forStreamedAudioSeconds: 10), 6.0, accuracy: 0.0001)
        XCTAssertEqual(policy.timeoutSeconds(forStreamedAudioSeconds: 500), 12.0, accuracy: 0.0001)
    }

    func test_init_sanitizesInvalidInputs() {
        let policy = StreamingFinalizationTimeoutPolicy(
            baseSeconds: .infinity,
            secondsPerAudioSecond: -.infinity,
            maxSeconds: -1
        )

        XCTAssertEqual(policy.timeoutSeconds(forStreamedAudioSeconds: 0), 5.0, accuracy: 0.0001)
        XCTAssertEqual(policy.timeoutSeconds(forStreamedAudioSeconds: 100), 5.0, accuracy: 0.0001)
    }
}
