import SwiftUI

// MARK: - State Management

public enum HUDMode: Equatable {
    case idle
    case recording
    case processing
}

public final class HUDState: ObservableObject {
    @Published public var mode: HUDMode = .idle
    @Published public var average: Float = 0
    @Published public var peak: Float = 0
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var processingMessage: String = "Transcribing"
    
    private var timer: Timer?
    
    public init() {}
    
    public func startRecording() {
        mode = .recording
        recordingDuration = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    public func startProcessing(message: String = "Transcribing") {
        mode = .processing
        processingMessage = message
        timer?.invalidate()
        timer = nil
    }
    
    public func stop() {
        mode = .idle
        timer?.invalidate()
        timer = nil
        recordingDuration = 0
        average = 0
        peak = 0
        processingMessage = "Transcribing"
    }
}

// MARK: - Design System

private enum Design {
    // Dimensions - consistent 8px radius for unified shape language
    static let widthRecording: CGFloat = 220
    static let heightRecording: CGFloat = 44
    static let widthIdle: CGFloat = 120
    static let heightIdle: CGFloat = 32
    static let cornerRadius: CGFloat = 8
    
    // Typography - distinctive hierarchy
    static let fontLabel = Font.system(size: 13, weight: .regular, design: .default)
    static let fontStatus = Font.system(size: 11, weight: .semibold, design: .default)
    static let fontTimer = Font.system(size: 14, weight: .semibold, design: .monospaced)
    
    // Colors - Minimal palette, no gradients, no purple
    static let borderIdle = Color.white.opacity(0.12)
    static let borderActive = Color.red.opacity(0.85)
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.45)
    static let accentIndicator = Color(red: 1.0, green: 0.25, blue: 0.25)
    static let segmentActive = Color.white.opacity(0.9)
    static let segmentInactive = Color.white.opacity(0.12)
    static let brandMark = Color.white.opacity(0.08)
    
    // Timing - Respecting 200ms constraint for feedback
    static let transitionDuration: Double = 0.18
    static let pulseDuration: Double = 1.2
    static let segmentUpdateDuration: Double = 0.06
    
    // Shadows
    static let shadowColor = Color.black.opacity(0.25)
    static let shadowRadius: CGFloat = 20
    static let shadowY: CGFloat = 4
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

/// 7-segment level meter with subtle V-shaped brand signature
private struct SegmentedMeter: View {
    let level: Float
    let segmentCount = 7
    
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
        .overlay(brandMark, alignment: .center)
    }
    
    /// Subtle "V" mark as brand signature - visible in negative space
    private var brandMark: some View {
        Text("V")
            .font(.system(size: 8, weight: .bold, design: .default))
            .foregroundStyle(Design.brandMark)
            .offset(y: 1)
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
    
    /// V-shaped height variation - subtle brand signature
    private var height: CGFloat {
        let baseHeight: CGFloat = isActive ? 10 : 5
        // Center segments are taller (subtle V shape)
        let centerIndex = CGFloat(totalCount - 1) / 2
        let distanceFromCenter = abs(CGFloat(index) - centerIndex)
        let vShape = max(0, 2 - distanceFromCenter) * 1.5
        return baseHeight + vShape
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
    
    @State private var isVisible = false
    
    public init(state: HUDState) {
        self.state = state
    }
    
    public var body: some View {
        content
            .padding(.horizontal, state.mode == .idle ? 16 : 14)
            .padding(.vertical, state.mode == .idle ? 8 : 11)
            .frame(
                width: state.mode == .idle ? Design.widthIdle : Design.widthRecording,
                height: state.mode == .idle ? Design.heightIdle : Design.heightRecording
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
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.97)
            .onAppear {
                withAnimation(.easeOut(duration: Design.transitionDuration)) {
                    isVisible = true
                }
            }
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
            // Left: Status indicator with subtle VOX mark
            HStack(spacing: 6) {
                PulsingIndicator()
                
                // Tight letter-spacing for iconic VOX mark
                Text("VOX")
                    .font(Design.fontStatus)
                    .foregroundStyle(Design.textSecondary)
                    .tracking(-0.5)
            }
            
            Spacer()
            
            // Center: Timer - more visual weight
            TimerDisplay(duration: state.recordingDuration)
            
            Spacer()
            
            // Right: Level meter with brand signature
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
    
    // MARK: - Container Styling
    
    private var containerBackground: some View {
        // No gradients - layered solid colors only
        Color.black.opacity(0.75)
    }
    
    private var containerBorder: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
            .stroke(
                borderColor,
                lineWidth: state.mode == .recording ? 1.5 : 1.0
            )
    }
    
    private var borderColor: Color {
        switch state.mode {
        case .idle:
            return Design.borderIdle
        case .recording:
            return Design.borderActive
        case .processing:
            return Design.textSecondary.opacity(0.4)
        }
    }
}

// MARK: - Preview

#Preview("Idle") {
    let idleState = HUDState()
    idleState.mode = .idle
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
    return HUDView(state: recordingState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Recording High") {
    let recordingState = HUDState()
    recordingState.mode = .recording
    recordingState.average = 0.85
    recordingState.recordingDuration = 145
    return HUDView(state: recordingState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Processing") {
    let processingState = HUDState()
    processingState.mode = .processing
    return HUDView(state: processingState)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}

#Preview("Reduced Motion") {
    let recordingState = HUDState()
    recordingState.mode = .recording
    recordingState.average = 0.5
    recordingState.recordingDuration = 67
    return HUDView(state: recordingState)
        .environment(\.reducedMotion, true)
        .padding(40)
        .background(Color.gray.opacity(0.4))
}
