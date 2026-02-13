import XCTest
import SwiftUI
@testable import VoxAppKit

final class VoxCloudTokenTests: XCTestCase {

    override func tearDown() {
        // Clean up any stored tokens after each test
        KeychainHelper.delete(.voxCloudToken)
        super.tearDown()
    }

    // MARK: - KeychainHelper Tests for VoxCloudToken

    func testKeychainHelper_SaveAndLoadVoxCloudToken() {
        let token = "test-vox-cloud-token-12345"

        let saveResult = KeychainHelper.save(token, for: .voxCloudToken)
        XCTAssertTrue(saveResult, "Should successfully save token to keychain")

        let loadedToken = KeychainHelper.load(.voxCloudToken)
        XCTAssertEqual(loadedToken, token, "Should load the same token that was saved")
    }

    func testKeychainHelper_LoadNonExistentToken() {
        // Ensure no token exists
        KeychainHelper.delete(.voxCloudToken)

        let loadedToken = KeychainHelper.load(.voxCloudToken)
        XCTAssertNil(loadedToken, "Should return nil for non-existent token")
    }

    func testKeychainHelper_DeleteVoxCloudToken() {
        let token = "test-vox-cloud-token-12345"

        KeychainHelper.save(token, for: .voxCloudToken)
        let loadedBeforeDelete = KeychainHelper.load(.voxCloudToken)
        XCTAssertEqual(loadedBeforeDelete, token, "Token should exist before deletion")

        let deleteResult = KeychainHelper.delete(.voxCloudToken)
        XCTAssertTrue(deleteResult, "Should successfully delete token from keychain")

        let loadedAfterDelete = KeychainHelper.load(.voxCloudToken)
        XCTAssertNil(loadedAfterDelete, "Token should be nil after deletion")
    }

    func testKeychainHelper_UpdateVoxCloudToken() {
        let firstToken = "first-token"
        let secondToken = "second-token"

        KeychainHelper.save(firstToken, for: .voxCloudToken)
        let loadedFirst = KeychainHelper.load(.voxCloudToken)
        XCTAssertEqual(loadedFirst, firstToken, "Should load first token")

        // Save should overwrite the existing token
        KeychainHelper.save(secondToken, for: .voxCloudToken)
        let loadedSecond = KeychainHelper.load(.voxCloudToken)
        XCTAssertEqual(loadedSecond, secondToken, "Should load second token after update")
    }

    // MARK: - PreferencesStore Tests

    func testPreferencesStore_VoxCloudToken() {
        let token = "preferences-store-test-token"
        let prefs = PreferencesStore.shared

        prefs.voxCloudToken = token
        XCTAssertEqual(prefs.voxCloudToken, token, "Should store and retrieve token via PreferencesStore")

        // Clean up
        prefs.voxCloudToken = ""
    }

    func testPreferencesStore_VoxCloudToken_Clear() {
        let prefs = PreferencesStore.shared

        prefs.voxCloudToken = "some-token"
        XCTAssertFalse(prefs.voxCloudToken.isEmpty, "Token should be set")

        prefs.voxCloudToken = ""
        XCTAssertTrue(prefs.voxCloudToken.isEmpty, "Token should be empty after clearing")
    }

    func testPreferencesStore_VoxCloudEnabled_Default() {
        let prefs = PreferencesStore.shared

        // Default should be false when no token is set
        XCTAssertFalse(prefs.voxCloudEnabled, "VoxCloudEnabled should default to false")
    }

    // MARK: - VoxCloudConnectionStatus Tests

    func testVoxCloudConnectionStatus_Equatable() {
        let status1: VoxCloudConnectionStatus = .ready(used: 100, remaining: 200)
        let status2: VoxCloudConnectionStatus = .ready(used: 100, remaining: 200)
        let status3: VoxCloudConnectionStatus = .ready(used: 150, remaining: 200)

        XCTAssertEqual(status1, status2, "Same status values should be equal")
        XCTAssertNotEqual(status1, status3, "Different status values should not be equal")
    }

    func testVoxCloudConnectionStatus_IsReady() {
        XCTAssertFalse(VoxCloudConnectionStatus.missing.isReady, "Missing should not be ready")
        XCTAssertFalse(VoxCloudConnectionStatus.testing.isReady, "Testing should not be ready")
        XCTAssertFalse(VoxCloudConnectionStatus.invalidToken.isReady, "InvalidToken should not be ready")
        XCTAssertFalse(VoxCloudConnectionStatus.error("test").isReady, "Error should not be ready")
        XCTAssertTrue(VoxCloudConnectionStatus.ready(used: 0, remaining: 100).isReady, "Ready should be ready")
    }

    func testVoxCloudConnectionStatus_DisplayText() {
        XCTAssertEqual(VoxCloudConnectionStatus.missing.displayText, "No token configured")
        XCTAssertEqual(VoxCloudConnectionStatus.testing.displayText, "Testing connection...")
        XCTAssertEqual(VoxCloudConnectionStatus.invalidToken.displayText, "Invalid token")
        XCTAssertEqual(VoxCloudConnectionStatus.error("test error").displayText, "Error: test error")
        XCTAssertEqual(VoxCloudConnectionStatus.ready(used: 100, remaining: 200).displayText, "Connected • 200 min remaining of 300 total")
    }

    // MARK: - VoxCloudQuota Tests

    func testVoxCloudQuota_Preview() {
        let quota = VoxCloudQuota.preview

        XCTAssertEqual(quota.used, 150)
        XCTAssertEqual(quota.remaining, 850)
        XCTAssertEqual(quota.total, 1000)
    }
}
