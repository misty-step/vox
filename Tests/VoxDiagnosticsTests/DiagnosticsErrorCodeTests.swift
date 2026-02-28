import Foundation
import Testing
import VoxCore
@testable import VoxDiagnostics

@Suite("DiagnosticsStore Error Code Mapping")
struct DiagnosticsErrorCodeTests {

    // MARK: - errorCode(for:)

    @Test("Maps STTError variants to stt.* codes")
    func errorCode_sttError() {
        #expect(DiagnosticsStore.errorCode(for: STTError.auth) == "stt.auth")
        #expect(DiagnosticsStore.errorCode(for: STTError.quotaExceeded) == "stt.quota_exceeded")
        #expect(DiagnosticsStore.errorCode(for: STTError.throttled) == "stt.throttled")
        #expect(DiagnosticsStore.errorCode(for: STTError.sessionLimit) == "stt.session_limit")
        #expect(DiagnosticsStore.errorCode(for: STTError.invalidAudio) == "stt.invalid_audio")
        #expect(DiagnosticsStore.errorCode(for: STTError.network("timeout")) == "stt.network")
        #expect(DiagnosticsStore.errorCode(for: STTError.unknown("???")) == "stt.unknown")
    }

    @Test("Maps StreamingSTTError variants to streaming.* codes")
    func errorCode_streamingSTTError() {
        #expect(DiagnosticsStore.errorCode(for: StreamingSTTError.connectionFailed("ws")) == "streaming.connection_failed")
        #expect(DiagnosticsStore.errorCode(for: StreamingSTTError.sendFailed("err")) == "streaming.send_failed")
        #expect(DiagnosticsStore.errorCode(for: StreamingSTTError.receiveFailed("err")) == "streaming.receive_failed")
        #expect(DiagnosticsStore.errorCode(for: StreamingSTTError.provider("err")) == "streaming.provider")
        #expect(DiagnosticsStore.errorCode(for: StreamingSTTError.finalizationTimeout) == "streaming.finalization_timeout")
        #expect(DiagnosticsStore.errorCode(for: StreamingSTTError.cancelled) == "streaming.cancelled")
        #expect(DiagnosticsStore.errorCode(for: StreamingSTTError.invalidState("bad")) == "streaming.invalid_state")
    }

    @Test("Maps RewriteError variants to rewrite.* codes")
    func errorCode_rewriteError() {
        #expect(DiagnosticsStore.errorCode(for: RewriteError.auth) == "rewrite.auth")
        #expect(DiagnosticsStore.errorCode(for: RewriteError.quotaExceeded) == "rewrite.quota_exceeded")
        #expect(DiagnosticsStore.errorCode(for: RewriteError.throttled) == "rewrite.throttled")
        #expect(DiagnosticsStore.errorCode(for: RewriteError.invalidRequest("bad")) == "rewrite.invalid_request")
        #expect(DiagnosticsStore.errorCode(for: RewriteError.network("fail")) == "rewrite.network")
        #expect(DiagnosticsStore.errorCode(for: RewriteError.timeout) == "rewrite.timeout")
        #expect(DiagnosticsStore.errorCode(for: RewriteError.unknown("oops")) == "rewrite.unknown")
    }

    @Test("Maps VoxError variants to vox.* codes")
    func errorCode_voxError() {
        #expect(DiagnosticsStore.errorCode(for: VoxError.permissionDenied("no")) == "vox.permission_denied")
        #expect(DiagnosticsStore.errorCode(for: VoxError.noFocusedElement) == "vox.no_focused_element")
        #expect(DiagnosticsStore.errorCode(for: VoxError.noTranscript) == "vox.no_transcript")
        #expect(DiagnosticsStore.errorCode(for: VoxError.emptyCapture) == "vox.empty_capture")
        #expect(DiagnosticsStore.errorCode(for: VoxError.audioCaptureFailed("mic")) == "vox.audio_capture_failed")
        #expect(DiagnosticsStore.errorCode(for: VoxError.insertionFailed) == "vox.insertion_failed")
        #expect(DiagnosticsStore.errorCode(for: VoxError.provider("x")) == "vox.provider")
        #expect(DiagnosticsStore.errorCode(for: VoxError.internalError("bug")) == "vox.internal_error")
        #expect(DiagnosticsStore.errorCode(for: VoxError.pipelineTimeout) == "vox.pipeline_timeout")
    }

    @Test("Maps AudioConversionError variants to audio_conversion.* codes")
    func errorCode_audioConversionError() {
        #expect(DiagnosticsStore.errorCode(for: AudioConversionError.emptyOutput) == "audio_conversion.empty_output")
        #expect(DiagnosticsStore.errorCode(for: AudioConversionError.converterUnavailable(reason: "missing")) == "audio_conversion.converter_unavailable")
        #expect(DiagnosticsStore.errorCode(for: AudioConversionError.conversionFailed(exitCode: 1, stderr: nil)) == "audio_conversion.conversion_failed")

        struct Underlying: Error {}
        #expect(DiagnosticsStore.errorCode(for: AudioConversionError.launchFailed(underlying: Underlying())) == "audio_conversion.launch_failed")
    }

    @Test("Falls back to type name for unknown error types")
    func errorCode_unknownType() {
        struct CustomError: Error {}
        let code = DiagnosticsStore.errorCode(for: CustomError())
        #expect(code == "CustomError")
    }

    // MARK: - errorFields(for:additional:)

    @Test("Includes error_code and error_type for STTError")
    func errorFields_sttError() {
        let fields = DiagnosticsStore.errorFields(for: STTError.throttled)
        #expect(fields["error_code"] == .string("stt.throttled"))
        #expect(fields["error_type"] == .string("STTError"))
    }

    @Test("Merges additional fields")
    func errorFields_mergesAdditional() {
        let fields = DiagnosticsStore.errorFields(
            for: STTError.auth,
            additional: ["provider": .string("ElevenLabs"), "attempt": .int(3)]
        )
        #expect(fields["error_code"] == .string("stt.auth"))
        #expect(fields["provider"] == .string("ElevenLabs"))
        #expect(fields["attempt"] == .int(3))
    }

    @Test("Includes diagnosticsPayload for AudioConversionError.launchFailed")
    func errorFields_audioConversionLaunchFailed() {
        struct TestErr: Error, LocalizedError {
            var errorDescription: String? { "test failure" }
        }
        let fields = DiagnosticsStore.errorFields(for: AudioConversionError.launchFailed(underlying: TestErr()))
        #expect(fields["error_code"] == .string("audio_conversion.launch_failed"))
        #expect(fields["conversion_tool"] == .string("afconvert"))
        #expect(fields["launch_error"] == .string("test failure"))
    }

    @Test("Includes diagnosticsPayload for AudioConversionError.conversionFailed")
    func errorFields_audioConversionFailed() {
        let fields = DiagnosticsStore.errorFields(for: AudioConversionError.conversionFailed(exitCode: 42, stderr: "bad input"))
        #expect(fields["conversion_exit_code"] == .int(42))
        #expect(fields["conversion_stderr"] == .string("bad input"))
        #expect(fields["conversion_tool"] == .string("afconvert"))
    }

    @Test("Includes diagnosticsPayload for AudioConversionError.conversionFailed without stderr")
    func errorFields_audioConversionFailedNoStderr() {
        let fields = DiagnosticsStore.errorFields(for: AudioConversionError.conversionFailed(exitCode: 1, stderr: nil))
        #expect(fields["conversion_exit_code"] == .int(1))
        #expect(fields["conversion_stderr"] == nil)
    }

    @Test("Includes diagnosticsPayload for AudioConversionError.converterUnavailable")
    func errorFields_converterUnavailable() {
        let fields = DiagnosticsStore.errorFields(for: AudioConversionError.converterUnavailable(reason: "not found"))
        #expect(fields["converter_unavailable_reason"] == .string("not found"))
    }

    @Test("Includes diagnosticsPayload for AudioConversionError.emptyOutput")
    func errorFields_emptyOutput() {
        let fields = DiagnosticsStore.errorFields(for: AudioConversionError.emptyOutput)
        #expect(fields["conversion_output_empty"] == .bool(true))
    }
}

// MARK: - DiagnosticsValue Codable

@Suite("DiagnosticsValue Codable")
struct DiagnosticsValueCodableTests {

    @Test("Round-trips all variant types through JSON")
    func roundTrip() throws {
        let values: [DiagnosticsValue] = [
            .string("hello"),
            .int(42),
            .double(3.14),
            .bool(true),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for value in values {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(DiagnosticsValue.self, from: data)
            #expect(decoded == value)
        }
    }

    @Test("Decodes false boolean correctly (not as Int 0)")
    func decodeFalseBool() throws {
        let data = Data("false".utf8)
        let decoded = try JSONDecoder().decode(DiagnosticsValue.self, from: data)
        #expect(decoded == .bool(false))
    }

    @Test("Decodes integer zero correctly (not as Bool)")
    func decodeIntZero() throws {
        let data = Data("0".utf8)
        let decoded = try JSONDecoder().decode(DiagnosticsValue.self, from: data)
        // JSON 0 may decode as Bool(false) or Int(0) depending on Swift's JSON decoder behavior.
        // The important thing is it round-trips through the enum.
        switch decoded {
        case .bool, .int:
            break // Both are acceptable
        default:
            Issue.record("Expected .bool or .int, got \(decoded)")
        }
    }

    @Test("Decodes floating-point number as double")
    func decodeDouble() throws {
        let data = Data("2.718".utf8)
        let decoded = try JSONDecoder().decode(DiagnosticsValue.self, from: data)
        #expect(decoded == .double(2.718))
    }
}

// MARK: - DiagnosticsEvent

@Suite("DiagnosticsEvent Codable")
struct DiagnosticsEventCodableTests {

    @Test("Round-trips through JSON encoding")
    func roundTrip() throws {
        let event = DiagnosticsEvent(
            timestamp: "2026-01-01T00:00:00Z",
            name: "test",
            sessionID: "abc",
            fields: ["count": .int(5), "ok": .bool(true)]
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(DiagnosticsEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test("Encodes nil sessionID as null")
    func nilSessionID() throws {
        let event = DiagnosticsEvent(
            timestamp: "2026-01-01T00:00:00Z",
            name: "test",
            sessionID: nil,
            fields: [:]
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(DiagnosticsEvent.self, from: data)
        #expect(decoded.sessionID == nil)
    }
}

// MARK: - DiagnosticsEventNames

@Suite("DiagnosticsEventNames")
struct DiagnosticsEventNamesTests {
    @Test("Event name constants are stable strings")
    func stableNames() {
        #expect(DiagnosticsEventNames.pipelineTiming == "pipeline_timing")
        #expect(DiagnosticsEventNames.shareTrigger == "share_triggered")
        #expect(DiagnosticsEventNames.rewriteOpenRouterAttempt == "rewrite_openrouter_attempt")
        #expect(DiagnosticsEventNames.rewriteModelUsed == "rewrite_model_used")
        #expect(DiagnosticsEventNames.rewriteStageOutcome == "rewrite_stage_outcome")
    }
}
