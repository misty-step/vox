import Testing
import Combine
@testable import VoxAppKit

@Suite("HotkeyState")
@MainActor
struct HotkeyStateTests {

    @Test("defaults to available")
    func defaults() {
        let state = HotkeyState()
        #expect(state.isAvailable == true)
    }

    @Test("init with unavailable preserves value")
    func initUnavailable() {
        let state = HotkeyState(isAvailable: false)
        #expect(state.isAvailable == false)
    }

    @Test("isAvailable mutates")
    func isAvailableMutation() {
        let state = HotkeyState(isAvailable: true)
        state.isAvailable = false
        #expect(state.isAvailable == false)
    }

    @Test("onRetry closure is invoked")
    func onRetryInvocation() {
        var retried = false
        let state = HotkeyState(isAvailable: true, onRetry: { retried = true })
        state.onRetry()
        #expect(retried == true)
    }

    @Test("onRetry can be replaced")
    func onRetryReplacement() {
        var first = false
        var second = false
        let state = HotkeyState(isAvailable: true, onRetry: { first = true })
        state.onRetry = { second = true }
        state.onRetry()
        #expect(first == false)
        #expect(second == true)
    }

    @Test("default onRetry is callable no-op")
    func defaultOnRetryNoOp() {
        let state = HotkeyState()
        state.onRetry() // must not crash
    }

    @Test("isAvailable publishes changes")
    func publishesChanges() {
        let state = HotkeyState(isAvailable: true)
        var published = false
        let cancellable = state.$isAvailable.dropFirst().sink { _ in published = true }
        state.isAvailable = false
        #expect(published == true)
        _ = cancellable
    }
}

@Suite("SettingsWindowController hotkey state")
@MainActor
struct SettingsWindowControllerTests {

    @Test("init reflects initial hotkeyAvailable")
    func initHotkeyAvailable() {
        let controller = SettingsWindowController(hotkeyAvailable: false)
        #expect(controller.hotkeyState.isAvailable == false)
    }

    @Test("updateHotkeyAvailability sets unavailable")
    func updateToUnavailable() {
        let controller = SettingsWindowController()
        controller.updateHotkeyAvailability(false)
        #expect(controller.hotkeyState.isAvailable == false)
    }

    @Test("updateHotkeyAvailability sets available after unavailable")
    func updateToAvailable() {
        let controller = SettingsWindowController()
        controller.updateHotkeyAvailability(false)
        controller.updateHotkeyAvailability(true)
        #expect(controller.hotkeyState.isAvailable == true)
    }

    @Test("updateHotkeyAvailability replaces retry closure")
    func updateRetryCallback() {
        var called = false
        let controller = SettingsWindowController()
        controller.updateHotkeyAvailability(false, onRetry: { called = true })
        controller.hotkeyState.onRetry()
        #expect(called == true)
    }

    @Test("updateHotkeyAvailability without retry keeps existing closure")
    func updateWithoutRetryKeepsExisting() {
        var called = false
        let controller = SettingsWindowController(onRetryHotkey: { called = true })
        controller.updateHotkeyAvailability(false)
        controller.hotkeyState.onRetry()
        #expect(called == true)
    }

    @Test("default init has hotkey available")
    func defaultInitAvailable() {
        let controller = SettingsWindowController()
        #expect(controller.hotkeyState.isAvailable == true)
    }
}
