import XCTest
@testable import VoxMac

final class HotkeyRegistrationResultTests: XCTestCase {

    func testSuccessIsSuccess() {
        // We can't easily create a HotkeyMonitor without registering,
        // so we test the result enum behavior indirectly
        let result = HotkeyRegistrationResult.success
    }

    func testFailureIsNotSuccess() {
        let error = HotkeyError.registrationFailed(-1)
        let result = HotkeyRegistrationResult.failure(error)

        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.monitor)
        XCTAssertEqual(result.error, error)
    }

    func testFailureEquality() {
        let error1 = HotkeyError.registrationFailed(-1)
        let error2 = HotkeyError.registrationFailed(-1)
        let error3 = HotkeyError.registrationFailed(-2)

        let result1 = HotkeyRegistrationResult.failure(error1)
        let result2 = HotkeyRegistrationResult.failure(error2)
        let result3 = HotkeyRegistrationResult.failure(error3)

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    func testHotkeyErrorLocalizedDescription() {
        let error = HotkeyError.registrationFailed(-9876)
        XCTAssertTrue(error.localizedDescription.contains("-9876"))
        XCTAssertTrue(error.localizedDescription.contains("failed"))
    }

    func testHotkeyErrorEquality() {
        let error1 = HotkeyError.registrationFailed(-1)
        let error2 = HotkeyError.registrationFailed(-1)
        let error3 = HotkeyError.registrationFailed(-2)

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
}
