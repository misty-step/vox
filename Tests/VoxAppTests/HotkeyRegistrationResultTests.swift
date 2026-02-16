import XCTest
@testable import VoxMac

final class HotkeyRegistrationResultTests: XCTestCase {

    func test_successResult_isSuccessAndHasMonitor() {
        let result = HotkeyRegistrationResult.successResult
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.monitor)
    }

    func test_failureResult_isNotSuccessAndHasError() {
        let error = HotkeyError.registrationFailed(-1)
        let result = HotkeyRegistrationResult.failureResult(error)

        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.monitor)
        XCTAssertEqual(result.error, error)
    }

    func test_failureResult_equalityByErrorCode() {
        let result1 = HotkeyRegistrationResult.failureResult(.registrationFailed(-1))
        let result2 = HotkeyRegistrationResult.failureResult(.registrationFailed(-1))
        let result3 = HotkeyRegistrationResult.failureResult(.registrationFailed(-2))

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    func test_localizedDescription_containsErrorCode() {
        let error = HotkeyError.registrationFailed(-9876)
        XCTAssertTrue(error.localizedDescription.contains("-9876"))
    }

    func test_localizedDescription_dispatchesThroughErrorExistential() {
        let error: Error = HotkeyError.registrationFailed(-42)
        XCTAssertTrue(error.localizedDescription.contains("-42"))
    }

    func test_hotkeyError_equalityByCode() {
        XCTAssertEqual(HotkeyError.registrationFailed(-1), HotkeyError.registrationFailed(-1))
        XCTAssertNotEqual(HotkeyError.registrationFailed(-1), HotkeyError.registrationFailed(-2))
    }
}
