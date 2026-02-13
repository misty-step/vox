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
    @Published public var processingMessage: String = "Processing"
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

    public func startProcessing(message: String = "Processing") {
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
        processingMessage = "Processing"
    }
}

// MARK: - Design System

enum HUDLayout {
    static let expandedWidth: CGFloat = 170
    static let expandedHeight: CGFloat = 40
}

private enum Design {
    static let width = HUDLayout.expandedWidth
    static let height = HUDLayout.expandedHeight
    // Timing
    static let fadeOutDuration: Double = 0.18
    static let transitionDuration: Double = 0.18
    static let successDisplayDuration = HUDTiming.successDisplayDuration

    // Colors
    static let red = Color(red: 255.0 / 255, green: 69.0 / 255, blue: 58.0 / 255)
    static let blue = Color(red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255)
    static let green = Color(red: 48.0 / 255, green: 209.0 / 255, blue: 88.0 / 255)

    // Shadows
    static let shadowColor = Color.black.opacity(0.22)
    static let shadowRadius: CGFloat = 16
    static let shadowY: CGFloat = 3

    // Typography
    static let timerFont = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let labelFont = Font.system(size: 12, weight: .medium)
    static let textSecondary = Color.white.opacity(0.55)
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

// MARK: - Icon Components

/// Mutable container for frame-by-frame level smoothing, avoiding @State value-type limitations.
private final class LevelSmoothing {
    var value: Double = 0

    /// Asymmetric EMA: fast attack (voice onset), slow release (natural decay).
    func smooth(toward target: Double) -> Double {
        let factor = target > value ? 0.3 : 0.15
        value += (target - value) * factor
        return value
    }
}

/// Pulsing red dot for recording state. Gentle breathing baseline with smoothed audio level boost.
private struct RecordingDot: View {
    let level: Float
    @Environment(\.reducedMotion) private var reducedMotion
    @State private var smoothing = LevelSmoothing()

    var body: some View {
        if reducedMotion {
            Circle()
                .fill(Design.red)
                .frame(width: 8, height: 8)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let breathPhase = elapsed.truncatingRemainder(dividingBy: 1.8) / 1.8
                let breathT = sin(breathPhase * .pi)
                // Breathing baseline: scale 0.85–1.05, opacity 0.5–0.65
                let breathScale = 0.85 + 0.20 * breathT
                let breathOpacity = 0.5 + 0.15 * breathT
                // Smoothed audio level boost — pow curve expands low signals, EMA removes jitter
                let lvl = smoothing.smooth(toward: pow(Double(level), 0.65))
                let scale = breathScale + lvl * 0.7
                let opacity = min(1.0, breathOpacity + lvl * 0.45)

                Circle()
                    .fill(Design.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
    }
}

/// Spinning blue arc for processing state.
private struct ProcessingSpinner: View {
    @Environment(\.reducedMotion) private var reducedMotion

    private let radius: CGFloat = 5
    private let strokeWidth: CGFloat = 1.5

    var body: some View {
        if reducedMotion {
            Circle()
                .stroke(Design.blue, lineWidth: strokeWidth)
                .frame(width: radius * 2, height: radius * 2)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let rotation = (elapsed.truncatingRemainder(dividingBy: 0.8) / 0.8) * 360

                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(Design.blue, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(rotation))
            }
        }
    }
}

/// Animated green checkmark for done state.
private struct CheckMark: View {
    @Environment(\.reducedMotion) private var reducedMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        CheckShape()
            .trim(from: 0, to: progress)
            .stroke(Design.green, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .frame(width: 14, height: 14)
            .onAppear {
                if reducedMotion {
                    progress = 1
                } else {
                    withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                        progress = 1
                    }
                }
            }
            .onDisappear {
                progress = 0
            }
    }
}

/// Path for the checkmark — three-point polyline matching the prototype.
private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Normalized from SVG viewBox 0 0 16 16, points: (4.5,8) (6.8,10.5) (11.5,5.5)
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.425, y: h * 0.656))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.344))
        return path
    }
}

// MARK: - Timer Display

private struct TimerDisplay: View {
    let duration: TimeInterval

    private var formattedTime: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        Text(formattedTime)
            .font(Design.timerFont)
            .foregroundStyle(Design.textSecondary)
            .monospacedDigit()
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
        HStack(spacing: 6) {
            iconZone
                .frame(width: 28, height: 28)
            Spacer()
            textZone
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(width: Design.width, height: Design.height)
        .background(containerBackground)
        .clipShape(Capsule())
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

    // MARK: - Icon Zone (left)

    @ViewBuilder
    private var iconZone: some View {
        switch state.mode {
        case .idle:
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 8, height: 8)
        case .recording:
            RecordingDot(level: state.average)
                .background(
                    Circle()
                        .fill(Design.red.opacity(0.25))
                        .frame(width: 20, height: 20)
                        .blur(radius: 8)
                )
        case .processing:
            ProcessingSpinner()
                .background(
                    Circle()
                        .fill(Design.blue.opacity(0.20))
                        .frame(width: 18, height: 18)
                        .blur(radius: 7)
                )
        case .success:
            CheckMark()
                .background(
                    Circle()
                        .fill(Design.green.opacity(0.22))
                        .frame(width: 20, height: 20)
                        .blur(radius: 8)
                )
        }
    }

    // MARK: - Text Zone (right)

    @ViewBuilder
    private var textZone: some View {
        switch state.mode {
        case .idle:
            Text("Ready")
                .font(Design.labelFont)
                .foregroundStyle(Color.white.opacity(0.3))
        case .recording:
            TimerDisplay(duration: state.recordingDuration)
        case .processing:
            Text(state.processingMessage)
                .font(Design.labelFont)
                .foregroundStyle(Design.textSecondary)
        case .success:
            Text("Done")
                .font(Design.labelFont)
                .foregroundStyle(Design.green)
        }
    }

    // MARK: - Container Styling

    private var containerBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .fill(Color.black.opacity(0.36))
            )
    }

    private var containerBorder: some View {
        Capsule()
            .inset(by: 0.5)
            .stroke(Color.white.opacity(0.10), lineWidth: 1.0)
    }
}

// MARK: - Preview

#Preview("Idle") {
    let state = HUDState()
    state.mode = .idle
    state.isVisible = true
    return HUDView(state: state)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Recording") {
    let state = HUDState()
    state.mode = .recording
    state.recordingDuration = 83
    state.isVisible = true
    return HUDView(state: state)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Processing") {
    let state = HUDState()
    state.mode = .processing
    state.isVisible = true
    return HUDView(state: state)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Done") {
    let state = HUDState()
    state.mode = .success
    state.isVisible = true
    return HUDView(state: state)
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
