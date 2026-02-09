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
    static let successDisplayDuration: Double = 0.5
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
    static let expandedWidth: CGFloat = 236
    static let expandedHeight: CGFloat = 48
    static let compactWidth: CGFloat = 132
    static let compactHeight: CGFloat = 34
}

private enum Design {
    // Dimensions
    static let widthRecording = HUDLayout.expandedWidth
    static let heightRecording = HUDLayout.expandedHeight
    static let widthIdle = HUDLayout.compactWidth
    static let heightIdle = HUDLayout.compactHeight
    static let cornerRadius: CGFloat = 10

    // Typography
    static let fontLabel = Font.system(size: 13, weight: .medium, design: .rounded)
    static let fontStatus = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let fontTimer = Font.system(size: 14, weight: .semibold, design: .monospaced)

    // Colors - restrained, no heavy gradients
    static let borderIdle = Color.white.opacity(0.16)
    static let borderActive = Color.white.opacity(0.34)
    static let borderProcessing = Color.white.opacity(0.26)
    static let borderSuccess = Color.green.opacity(0.5)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.58)
    static let accentIndicator = Color(
        red: BrandIdentity.accent.red,
        green: BrandIdentity.accent.green,
        blue: BrandIdentity.accent.blue
    )
    static let segmentActive = Color.white.opacity(0.92)
    static let segmentInactive = Color.white.opacity(0.2)

    // Timing
    static let transitionDuration: Double = 0.18
    static let fadeOutDuration: Double = 0.18
    static let contentTransitionDuration: Double = 0.15
    static let successDisplayDuration = HUDTiming.successDisplayDuration
    static let pulseDuration: Double = 1.2
    static let segmentUpdateDuration: Double = 0.06

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

// MARK: - Components

/// Pulsing indicator dot - animated with transform only (scale)
private struct PulsingIndicator: View {
    @Environment(\.reducedMotion) private var reducedMotion
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(Design.accentIndicator)
            .frame(width: 8, height: 8)
            .scaleEffect(reducedMotion ? 1.0 : (isPulsing ? 1.15 : 0.85))
            .opacity(reducedMotion ? 1.0 : (isPulsing ? 1.0 : 0.75))
            .onAppear {
                guard !reducedMotion else { return }
                withAnimation(.easeInOut(duration: Design.pulseDuration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

/// Segmented level meter with restrained active/inactive contrast.
private struct SegmentedMeter: View {
    let level: Float
    let segmentCount = 8
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segmentCount, id: \.self) { index in
                SegmentBar(
                    index: index,
                    totalCount: segmentCount,
                    level: level
                )
            }
        }
        .frame(height: 14)
    }
}

private struct SegmentBar: View {
    let index: Int
    let totalCount: Int
    let level: Float
    
    private var isActive: Bool {
        let threshold = Float(index + 1) / Float(totalCount)
        return level >= threshold
    }
    
    private var height: CGFloat {
        isActive ? 11 : 6
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(isActive ? Design.segmentActive : Design.segmentInactive)
            .frame(width: 4, height: height)
            .animation(.easeOut(duration: Design.segmentUpdateDuration), value: isActive)
    }
}

/// Processing spinner - geometric precision using rotation
private struct ProcessingSpinner: View {
    @Environment(\.reducedMotion) private var reducedMotion
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.75)
            .stroke(Design.textPrimary, lineWidth: 1.5)
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(reducedMotion ? 0 : rotation))
            .onAppear {
                guard !reducedMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

/// Timer display - technical precision with distinctive presence
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

// MARK: - Main HUD View

public struct HUDView: View {
    @ObservedObject var state: HUDState
    @Environment(\.reducedMotion) private var reducedMotion

    public init(state: HUDState) {
        self.state = state
    }

    private var isCompact: Bool {
        state.mode == .idle
    }

    public var body: some View {
        content
            .animation(
                reducedMotion ? nil : .easeInOut(duration: Design.contentTransitionDuration),
                value: state.mode
            )
            .padding(.horizontal, isCompact ? 16 : 14)
            .padding(.vertical, isCompact ? 8 : 11)
            .frame(
                width: isCompact ? Design.widthIdle : Design.widthRecording,
                height: isCompact ? Design.heightIdle : Design.heightRecording
            )
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
            idleContent
        case .recording:
            recordingContent
        case .processing:
            processingContent
        case .success:
            successContent
        }
    }
    
    private var idleContent: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Design.textSecondary)
                .frame(width: 5, height: 5)
            
            Text("Ready")
                .font(Design.fontLabel)
                .foregroundStyle(Design.textSecondary)
        }
    }
    
    private var recordingContent: some View {
        HStack(spacing: 12) {
            PulsingIndicator()
            
            Spacer()
            
            TimerDisplay(duration: state.recordingDuration)
            
            Spacer()
            
            SegmentedMeter(level: state.average)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var processingContent: some View {
        HStack(spacing: 10) {
            ProcessingSpinner()
            
            // Specific action, not generic "Processing"
            Text(state.processingMessage)
                .font(Design.fontLabel)
                .foregroundStyle(Design.textPrimary)
        }
    }
    
    private var successContent: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.green.opacity(0.9))

                Text("Done")
                    .font(Design.fontLabel)
                    .foregroundStyle(Design.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
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
            return Design.borderActive
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

#Preview("Recording Low") {
    let recordingState = HUDState()
    recordingState.mode = .recording
    recordingState.average = 0.2
    recordingState.recordingDuration = 12
    recordingState.isVisible = true
    return HUDView(state: recordingState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Recording High") {
    let recordingState = HUDState()
    recordingState.mode = .recording
    recordingState.average = 0.85
    recordingState.recordingDuration = 145
    recordingState.isVisible = true
    return HUDView(state: recordingState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Processing") {
    let processingState = HUDState()
    processingState.mode = .processing
    processingState.isVisible = true
    return HUDView(state: processingState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Success") {
    let successState = HUDState()
    successState.mode = .success
    successState.isVisible = true
    return HUDView(state: successState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Reduced Motion") {
    let recordingState = HUDState()
    recordingState.mode = .recording
    recordingState.average = 0.5
    recordingState.recordingDuration = 67
    recordingState.isVisible = true
    return HUDView(state: recordingState)
        .environment(\.reducedMotion, true)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}
