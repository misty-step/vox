import SwiftUI

public enum HUDMode {
    case idle
    case recording
    case processing
}

public final class HUDState: ObservableObject {
    @Published public var mode: HUDMode = .idle
    @Published public var average: Float = 0
    @Published public var peak: Float = 0

    public init() {}
}

public struct HUDView: View {
    @ObservedObject var state: HUDState

    public init(state: HUDState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            if state.mode == .processing {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            } else {
                waveform
            }

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(radius: 16)
    }

    private var label: String {
        switch state.mode {
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .processing: return "Processing"
        }
    }

    private var waveform: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    let height = barHeight(time: t, index: index)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.green.opacity(0.9))
                        .frame(width: 6, height: height)
                }
            }
            .frame(height: 34)
            .animation(.easeInOut(duration: 0.15), value: state.average)
        }
    }

    private func barHeight(time: TimeInterval, index: Int) -> CGFloat {
        let level = max(Double(state.average), 0.08)
        let pulse = sin(time * 5 + Double(index) * 0.7) * 0.5 + 0.5
        let amplitude = (0.35 + level) * 28
        return CGFloat(8 + pulse * amplitude)
    }
}
