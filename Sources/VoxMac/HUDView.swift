import SwiftUI
import VoxCore

// MARK: - State Management

public enum HUDMode: Equatable {
    case idle
    case recording
    case processing
    case success
}

/// Timing constants shared between HUDView and HUDController.
enum HUDTiming {
    static let successDisplayDuration: Double = 1.2
}

@MainActor
public final class HUDState: ObservableObject {
    @Published public var mode: HUDMode = .idle
    @Published public var average: Float = 0
    @Published public var peak: Float = 0
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var processingMessage: String = "Transcribing"
    @Published public var isVisible: Bool = false

    private var timer: Timer?

    public init() {}

    public var accessibilityLabel: String {
        HUDAccessibility.label
    }

    public var accessibilityValue: String {
        HUDAccessibility.value(
            for: mode,
            recordingDuration: recordingDuration,
            processingMessage: processingMessage
        )
    }

    public func show() {
        isVisible = true
    }

    public func startRecording() {
        mode = .recording
        recordingDuration = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    public func startProcessing(message: String = "Transcribing") {
        mode = .processing
        processingMessage = message
        timer?.invalidate()
        timer = nil
    }

    public func startSuccess() {
        mode = .success
        timer?.invalidate()
        timer = nil
    }

    /// Triggers fade-out, then calls completion after animation duration.
    public func dismiss(reducedMotion: Bool, completion: @escaping () -> Void) {
        if reducedMotion {
            isVisible = false
            stop()
            completion()
        } else {
            isVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + Design.fadeOutDuration) {
                self.stop()
                completion()
            }
        }
    }

    public func stop() {
        mode = .idle
        isVisible = false
        timer?.invalidate()
        timer = nil
        recordingDuration = 0
        average = 0
        peak = 0
        processingMessage = "Transcribing"
    }
}

// MARK: - Design System

enum HUDLayout {
    static let expandedWidth: CGFloat = 260
    static let expandedHeight: CGFloat = 44
}

private enum Design {
    // Dimensions — fixed for all states
    static let width = HUDLayout.expandedWidth
    static let height = HUDLayout.expandedHeight
    static let cornerRadius: CGFloat = 10

    // Typography
    static let fontTimer = Font.system(size: 14, weight: .semibold, design: .monospaced)

    // Colors
    static let borderIdle = Color.white.opacity(0.14)
    static let borderRecording = Color.white.opacity(0.3)
    static let borderProcessing = Color.white.opacity(0.2)
    static let borderSuccess = Color.green.opacity(0.45)
    static let textPrimary = Color.white.opacity(0.92)
    static let segmentActive = Color.white.opacity(0.9)
    static let segmentInactive = Color.white.opacity(0.08)
    static let segmentGreen = Color(red: 48.0 / 255, green: 209.0 / 255, blue: 88.0 / 255)

    // Timing
    static let fadeOutDuration: Double = 0.18
    static let transitionDuration: Double = 0.18
    static let successDisplayDuration = HUDTiming.successDisplayDuration

    // KITT sweep
    static let sweepCycleDuration: Double = 2.0
    static let sweepStaggerDelay: Double = 0.06
    static let segmentCount: Int = 20

    // Shadows
    static let shadowColor = Color.black.opacity(0.22)
    static let shadowRadius: CGFloat = 16
    static let shadowY: CGFloat = 3
}

// MARK: - Accessibility

private struct ReducedMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var reducedMotion: Bool {
        get { self[ReducedMotionKey.self] }
        set { self[ReducedMotionKey.self] = newValue }
    }
}

// MARK: - KITT Sweep Interpolation

/// Maps a normalized phase (0–1) to segment opacity using the KITT keyframe curve.
private func kittOpacity(phase: Double) -> Double {
    let p = phase < 0 ? phase + 1.0 : (phase >= 1.0 ? phase - 1.0 : phase)
    if p < 0.12 {
        return 0.06 + (0.95 - 0.06) * (p / 0.12)
    } else if p < 0.25 {
        return 0.95 + (0.35 - 0.95) * ((p - 0.12) / 0.13)
    } else if p < 0.45 {
        return 0.35 + (0.08 - 0.35) * ((p - 0.25) / 0.20)
    } else {
        return 0.08 + (0.06 - 0.08) * min(1, (p - 0.45) / 0.55)
    }
}

/// Maps a normalized phase (0–1) to segment height using the KITT keyframe curve.
private func kittHeight(phase: Double) -> CGFloat {
    let p = phase < 0 ? phase + 1.0 : (phase >= 1.0 ? phase - 1.0 : phase)
    if p < 0.12 {
        return 3 + (14 - 3) * CGFloat(p / 0.12)
    } else if p < 0.25 {
        return 14 + (7 - 14) * CGFloat((p - 0.12) / 0.13)
    } else if p < 0.45 {
        return 7 + (4 - 7) * CGFloat((p - 0.25) / 0.20)
    } else {
        return 4 + (3 - 4) * CGFloat(min(1, (p - 0.45) / 0.55))
    }
}

// MARK: - Components

/// Timer display — monospaced digits, right-aligned in the capsule
private struct TimerDisplay: View {
    let duration: TimeInterval

    private var formattedTime: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        Text(formattedTime)
            .font(Design.fontTimer)
            .foregroundStyle(Design.textPrimary)
            .monospacedDigit()
    }
}

/// Level meter for recording — 20 segments respond to audio level
private struct LevelMeter: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Design.segmentCount, id: \.self) { index in
                LevelSegment(index: index, level: level)
            }
        }
        .frame(height: 14)
    }
}

private struct LevelSegment: View {
    let index: Int
    let level: Float

    private var isActive: Bool {
        let threshold = Float(index + 1) / Float(Design.segmentCount)
        return level >= threshold
    }

    private var segmentHeight: CGFloat {
        guard isActive else { return 3 }
        let normalized = CGFloat(index) / CGFloat(Design.segmentCount)
        let variation = 1.0 - abs(normalized - 0.4) * 0.8
        return 10 + 4 * variation
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color.white.opacity(isActive ? 0.9 : 0.08))
            .frame(maxWidth: .infinity)
            .frame(height: segmentHeight)
            .animation(.easeOut(duration: 0.06), value: isActive)
    }
}

/// KITT sweep animation for processing — L→R scanning beam, 2s cycle
private struct KITTSweepMeter: View {
    @Environment(\.reducedMotion) private var reducedMotion

    var body: some View {
        if reducedMotion {
            staticProcessingMeter
        } else {
            animatedSweepMeter
        }
    }

    private var staticProcessingMeter: some View {
        HStack(spacing: 2) {
            ForEach(0..<Design.segmentCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
            }
        }
        .frame(height: 14)
    }

    private var animatedSweepMeter: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<Design.segmentCount, id: \.self) { index in
                    let phase = sweepPhase(for: index, at: elapsed)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.white.opacity(kittOpacity(phase: phase)))
                        .frame(maxWidth: .infinity)
                        .frame(height: kittHeight(phase: phase))
                }
            }
            .frame(height: 14)
        }
    }

    private func sweepPhase(for index: Int, at time: TimeInterval) -> Double {
        let offset = Double(index) * Design.sweepStaggerDelay
        let raw = (time - offset).truncatingRemainder(dividingBy: Design.sweepCycleDuration)
        let normalized = raw / Design.sweepCycleDuration
        return normalized < 0 ? normalized + 1.0 : normalized
    }
}

/// Green cascade for success — segments fill L→R with staggered delay
private struct GreenCascadeMeter: View {
    @Environment(\.reducedMotion) private var reducedMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Design.segmentCount, id: \.self) { index in
                GreenCascadeSegment(index: index, reducedMotion: reducedMotion)
            }
        }
        .frame(height: 14)
    }
}

private struct GreenCascadeSegment: View {
    let index: Int
    let reducedMotion: Bool

    @State private var isFilled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(isFilled ? Design.segmentGreen.opacity(0.7) : Color.white.opacity(0.06))
            .frame(maxWidth: .infinity)
            .frame(height: isFilled ? 10 : 3)
            .onAppear {
                if reducedMotion {
                    isFilled = true
                } else {
                    withAnimation(.easeOut(duration: 0.35).delay(Double(index) * 0.015)) {
                        isFilled = true
                    }
                }
            }
    }
}

/// Idle meter — all segments dim
private struct IdleMeter: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Design.segmentCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
            }
        }
        .frame(height: 14)
    }
}

// MARK: - Main HUD View

public struct HUDView: View {
    @ObservedObject var state: HUDState
    @Environment(\.reducedMotion) private var reducedMotion

    public init(state: HUDState) {
        self.state = state
    }

    public var body: some View {
        content
            .padding(.horizontal, 14)
            .frame(width: Design.width, height: Design.height)
            .background(containerBackground)
            .clipShape(RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous))
            .overlay(containerBorder)
            .shadow(
                color: Design.shadowColor,
                radius: Design.shadowRadius,
                x: 0,
                y: Design.shadowY
            )
            .opacity(state.isVisible ? 1.0 : 0.0)
            .scaleEffect(state.isVisible ? 1.0 : 0.97)
            .animation(
                reducedMotion ? nil : .easeOut(duration: Design.transitionDuration),
                value: state.isVisible
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(state.accessibilityLabel))
            .accessibilityValue(Text(state.accessibilityValue))
            .accessibilityHidden(!state.isVisible)
    }

    // MARK: - Content Views

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .idle:
            IdleMeter()
        case .recording:
            recordingContent
        case .processing:
            KITTSweepMeter()
        case .success:
            GreenCascadeMeter()
        }
    }

    private var recordingContent: some View {
        HStack(spacing: 8) {
            LevelMeter(level: state.average)
            TimerDisplay(duration: state.recordingDuration)
        }
    }

    // MARK: - Container Styling

    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.36))
            )
    }

    private var containerBorder: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: state.mode == .recording ? 1.4 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
                    .inset(by: 0.5)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
    }

    private var borderColor: Color {
        switch state.mode {
        case .idle:
            return Design.borderIdle
        case .recording:
            return Design.borderRecording
        case .processing:
            return Design.borderProcessing
        case .success:
            return Design.borderSuccess
        }
    }
}

// MARK: - Preview

#Preview("Idle") {
    let idleState = HUDState()
    idleState.mode = .idle
    idleState.isVisible = true
    return HUDView(state: idleState)
        .padding(40)
        .background(
            LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
}

#Preview("Recording") {
    let recordingState = HUDState()
    recordingState.mode = .recording
    recordingState.average = 0.4
    recordingState.recordingDuration = 83
    recordingState.isVisible = true
    return HUDView(state: recordingState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Processing — KITT Sweep") {
    let processingState = HUDState()
    processingState.mode = .processing
    processingState.isVisible = true
    return HUDView(state: processingState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Success — Green Cascade") {
    let successState = HUDState()
    successState.mode = .success
    successState.isVisible = true
    return HUDView(state: successState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Reduced Motion") {
    let state = HUDState()
    state.mode = .processing
    state.isVisible = true
    return HUDView(state: state)
        .environment(\.reducedMotion, true)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}
