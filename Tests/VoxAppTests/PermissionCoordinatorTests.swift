import XCTest
@testable import VoxApp

// Mock permission checker for testing
actor MockPermissionChecker: PermissionChecker {
    var microphoneStatus: PermissionStatus = .notDetermined
    var accessibilityStatus: PermissionStatus = .notDetermined

    var microphonePromptCount = 0
    var accessibilityPromptCount = 0

    func getMicrophoneStatus() async -> PermissionStatus {
        microphoneStatus
    }

    func getAccessibilityStatus() async -> PermissionStatus {
        accessibilityStatus
    }

    func requestMicrophoneAccess() async -> Bool {
        microphonePromptCount += 1
        if microphoneStatus == .notDetermined {
            microphoneStatus = .authorized
        }
        return microphoneStatus == .authorized
    }

    func requestAccessibilityAccess() async -> Bool {
        accessibilityPromptCount += 1
        if accessibilityStatus == .notDetermined {
            accessibilityStatus = .authorized
        }
        return accessibilityStatus == .authorized
    }

    func setMicrophoneStatus(_ status: PermissionStatus) {
        microphoneStatus = status
    }

    func setAccessibilityStatus(_ status: PermissionStatus) {
        accessibilityStatus = status
    }

    func getMicrophonePromptCount() -> Int { microphonePromptCount }
    func getAccessibilityPromptCount() -> Int { accessibilityPromptCount }
}

final class PermissionCoordinatorTests: XCTestCase {

    // Test: Returns cached result if already granted (mic)
    func testMicrophoneReturnsCachedResultIfGranted() async throws {
        let checker = MockPermissionChecker()
        let coordinator = PermissionCoordinatorImpl(checker: checker)

        await checker.setMicrophoneStatus(.authorized)

        // Call twice
        let result1 = await coordinator.ensureMicrophoneAccess()
        let result2 = await coordinator.ensureMicrophoneAccess()

        XCTAssertTrue(result1)
        XCTAssertTrue(result2)

        // Should not have prompted at all - already authorized
        let promptCount = await checker.getMicrophonePromptCount()
        XCTAssertEqual(promptCount, 0, "Should not prompt when already authorized")
    }

    // Test: Prompts once when not determined (mic)
    func testMicrophonePromptsOnceWhenNotDetermined() async throws {
        let checker = MockPermissionChecker()
        let coordinator = PermissionCoordinatorImpl(checker: checker)

        await checker.setMicrophoneStatus(.notDetermined)

        let result = await coordinator.ensureMicrophoneAccess()

        XCTAssertTrue(result)
        let promptCount = await checker.getMicrophonePromptCount()
        XCTAssertEqual(promptCount, 1)
    }

    // Test: Dedupes concurrent mic requests
    func testMicrophoneDedupesConcurrentRequests() async throws {
        let checker = MockPermissionChecker()
        let coordinator = PermissionCoordinatorImpl(checker: checker)

        await checker.setMicrophoneStatus(.notDetermined)

        // Launch multiple concurrent requests
        async let result1 = coordinator.ensureMicrophoneAccess()
        async let result2 = coordinator.ensureMicrophoneAccess()
        async let result3 = coordinator.ensureMicrophoneAccess()

        let results = await [result1, result2, result3]

        XCTAssertEqual(results, [true, true, true])

        // Should only have prompted once despite concurrent calls
        let promptCount = await checker.getMicrophonePromptCount()
        XCTAssertEqual(promptCount, 1, "Concurrent requests should coalesce into single prompt")
    }

    // Test: Returns false when denied (mic)
    func testMicrophoneReturnsFalseWhenDenied() async throws {
        let checker = MockPermissionChecker()
        let coordinator = PermissionCoordinatorImpl(checker: checker)

        await checker.setMicrophoneStatus(.denied)

        let result = await coordinator.ensureMicrophoneAccess()

        XCTAssertFalse(result)
    }

    // Test: Accessibility prompt called once per session
    func testAccessibilityPromptsOncePerSession() async throws {
        let checker = MockPermissionChecker()
        let coordinator = PermissionCoordinatorImpl(checker: checker)

        await checker.setAccessibilityStatus(.notDetermined)

        // Call multiple times
        _ = await coordinator.ensureAccessibilityAccess()
        _ = await coordinator.ensureAccessibilityAccess()
        _ = await coordinator.ensureAccessibilityAccess()

        // Should only prompt once
        let promptCount = await checker.getAccessibilityPromptCount()
        XCTAssertEqual(promptCount, 1, "Accessibility should only prompt once per session")
    }

    // Test: Returns cached accessibility result
    func testAccessibilityReturnsCachedResult() async throws {
        let checker = MockPermissionChecker()
        let coordinator = PermissionCoordinatorImpl(checker: checker)

        await checker.setAccessibilityStatus(.authorized)

        let result1 = await coordinator.ensureAccessibilityAccess()
        let result2 = await coordinator.ensureAccessibilityAccess()

        XCTAssertTrue(result1)
        XCTAssertTrue(result2)

        // No prompts needed - already authorized
        let promptCount = await checker.getAccessibilityPromptCount()
        XCTAssertEqual(promptCount, 0)
    }
}

