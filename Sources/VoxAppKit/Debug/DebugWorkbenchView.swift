import SwiftUI
import VoxCore

struct DebugWorkbenchView: View {
    @ObservedObject var store: DebugWorkbenchStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vox Debug Workbench")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(store.requests.count) requests")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.requests) { request in
                        RequestCard(request: request, onCopy: { store.copyToClipboard($0) })
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 880, minHeight: 560)
    }
}

private struct RequestCard: View {
    let request: DebugWorkbenchStore.RequestRecord
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(request.createdAt, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("ID: \(request.id)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("mode: \(request.processingLevel.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StatusBadge(status: request.status)
            }

            OutputPaneView(title: "Raw Transcript", pane: request.raw, onCopy: onCopy)
            OutputPaneView(title: "Clean Rewrite", pane: request.clean, onCopy: onCopy)
            OutputPaneView(title: "Polish Rewrite", pane: request.polish, onCopy: onCopy)

            let logs = request.logs.joined(separator: "\n")
            OutputPaneView(
                title: "Logs (tail)",
                pane: .init(state: .ready, text: logs.isEmpty ? "(no logs yet)" : logs),
                onCopy: onCopy,
                isMonospace: true
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
        )
    }
}

private struct StatusBadge: View {
    let status: DebugWorkbenchStore.RequestStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .recording:
            return .red
        case .processing:
            return .blue
        case .succeeded:
            return .green
        case .failed:
            return .orange
        case .cancelled:
            return .gray
        }
    }
}

private struct OutputPaneView: View {
    let title: String
    let pane: DebugWorkbenchStore.OutputPane
    let onCopy: (String) -> Void
    var isMonospace: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                switch pane.state {
                case .pending:
                    Text("pending")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                case .ready:
                    Button("Copy") {
                        onCopy(pane.text)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(pane.text.isEmpty)
                case .failed(let reason):
                    Text("failed: \(reason)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Group {
                switch pane.state {
                case .pending:
                    Text("(waiting…)")
                        .foregroundStyle(.secondary)
                case .ready:
                    Text(pane.text.isEmpty ? "(empty)" : pane.text)
                        .textSelection(.enabled)
                case .failed:
                    Text("(no output)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(isMonospace ? .system(.caption, design: .monospaced) : .system(.body, design: .default))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15)))
            )
        }
    }
}
