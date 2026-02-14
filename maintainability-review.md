# Maintainability & Developer Experience Review - Microphone Hot-swap

## Summary
The PR introduces live microphone monitoring and fallback UI, which is a great UX improvement. However, it introduces a potential singleton interference issue in `AudioDeviceObserver`, removes valuable developer previews in `HUDView`, and contains some redundant state management in `BasicsSection`.

## Investigation Notes
- [x] AudioDeviceObserver singleton lifecycle: Confirmed that `startListening`/`stopListening` will interfere if used by multiple views.
- [x] HUDView preview removal: Confirmed as a regression in DX.
- [x] BasicsSection state redundancy: Confirmed `@State devices` is redundant.
- [x] CoreAudio listener safety: Implementation is safe regarding threading and C-callback conversion.

## Findings

### 1. Singleton Interference in AudioDeviceObserver
**Severity: Major | Category: hidden-side-effects**
The `AudioDeviceObserver.shared` singleton uses a simple boolean `isListening` to manage its CoreAudio property listener. If multiple views (e.g., `BasicsSection` and a future audio settings view) both call `startListening` on appear and `stopListening` on disappear, the first view to disappear will stop the listener for all other active views.

**Evidence:**
`Sources/VoxMac/AudioDeviceManager.swift:73`
```swift
    public func stopListening() {
        guard isListening, let callback = propertyListener else { return }
        // ... removal logic ...
        isListening = false
        propertyListener = nil
    }
```

**Suggestion:**
Since `AudioDeviceObserver` is a singleton intended to provide live updates, consider starting the listener in `init` and keeping it active for the app's lifetime. Alternatively, implement a reference counter for `startListening`/`stopListening` calls.

---

### 2. Regression in Developer Experience (HUDView Previews)
**Severity: Major | Category: readability**
The PR removes all `#Preview` blocks from `HUDView.swift`, citing build environment issues with the `PreviewsMacros` plugin. Deleting these previews is a significant regression in developer experience for others whose environments do support them.

**Evidence:**
`Sources/VoxMac/HUDView.swift:409`
```swift
// MARK: - Preview
// Note: #Preview macros removed due to PreviewsMacros plugin unavailability in this build environment.
```

**Suggestion:**
Restore the previews. If they must be disabled for a specific environment, consider commenting them out or using a compiler flag, but do not delete the code.

---

### 3. Redundant State in BasicsSection
**Severity: Minor | Category: component-complexity**
`BasicsSection` maintains a `@State private var devices` array which it manually synchronizes with `deviceObserver.devices` via `onReceive`. Since `deviceObserver` is already an `@ObservedObject`, the view can (and should) use `deviceObserver.devices` directly to reduce complexity and potential sync bugs.

**Evidence:**
`Sources/VoxAppKit/Settings/BasicsSection.swift:10`
```swift
    @State private var devices: [AudioInputDevice] = []
```
and
`Sources/VoxAppKit/Settings/BasicsSection.swift:50`
```swift
        .onReceive(deviceObserver.$devices) { newDevices in
            devices = newDevices
        }
```

**Suggestion:**
Remove the `@State` variable and the `.onReceive` block. Update the `Picker` to iterate over `deviceObserver.devices` directly.

---

### 4. Flaky Test in AudioDeviceObserverTests
**Severity: Minor | Category: test-quality**
`testInitialDevicesLoaded` asserts that the device list is not empty. This test will fail in headless CI environments or on machines with no audio input devices connected.

**Evidence:**
`Tests/VoxAppTests/AudioDeviceObserverTests.swift:253`
```swift
    func testInitialDevicesLoaded() {
        // Device list should be populated on init
        XCTAssertFalse(observer.devices.isEmpty, "Devices should be loaded on initialization")
    }
```

**Suggestion:**
Use `try XCTSkipIf(AudioDeviceManager.inputDevices().isEmpty, ...)` to skip the test gracefully when no hardware is available, consistent with other tests in the same file.

## Verdict: WARN
The PR provides valuable functionality but introduces maintenance burdens regarding singleton lifecycle and DX regressions.
